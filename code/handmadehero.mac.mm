/*
 TODO(casey):  THIS IS NOT A FINAL PLATFORM LAYER!!!
 
 - Saved game locations
 - Getting a handle to our own executable file
 - Asset loading path
 - Threading (launch a thread)
 - Raw Input (support for multiple keyboards)
 - Sleep/timeBeginPeriod
 - ClipCursor() (for multimonitor support)
 - Fullscreen support
 - WM_SETCURSOR (control cursor visibility)
 - QueryCancelAutoplay
 - WM_ACTIVATEAPP (for when we are not the active application)
 - Blit speed improvements (BitBlt)
 - Hardware acceleration (OpenGL or Direct3D or BOTH??)
 - GetKeyboardLayout (for French keyboards, international WASD support)
 
 Just a partial list of stuff!!
 */

// TODO(casey): Implement sine ourselves
#include <Cocoa/Cocoa.h>

#include "casey/handmade.h"

#include <mach-o/dyld.h>
#include "AudioToolbox/AudioToolbox.h"
#include <sys/stat.h>
#include <dlfcn.h>
#include <mach/mach_time.h>

#include "handmadehero.mac.h"

global_variable BOOL GlobalRunning;
global_variable bool32 GlobalPause;
global_variable mac_offscreen_buffer GlobalBackbuffer;
global_variable void *GlobalSecondaryBuffer;
global_variable mach_timebase_info_data_t GlobalPerfCountFrequency;
global_variable mac_state MacState;

internal void
CatStrings(size_t SourceACount, char *SourceA,
           size_t SourceBCount, char *SourceB,
           size_t DestCount, char *Dest)
{
    // TODO(casey): Dest bounds checking!
    
    for(int Index = 0;
        Index < SourceACount;
        ++Index)
    {
        *Dest++ = *SourceA++;
    }

    for(int Index = 0;
        Index < SourceBCount;
        ++Index)
    {
        *Dest++ = *SourceB++;
    }

    *Dest++ = 0;
}

internal void
MacGetAppFileName(mac_state *State)
{
	uint32 buffsize = sizeof(State->AppFileName);
    if (_NSGetExecutablePath(State->AppFileName, &buffsize) == 0) {
		for(char *Scan = State->AppFileName;
			*Scan;
			++Scan)
		{
			if(*Scan == '/')
			{
				State->OnePastLastAppFileNameSlash = Scan + 1;
			}
		}
    }
}

internal int
StringLength(char *String)
{
    int Count = 0;
    while(*String++)
    {
        ++Count;
    }
    return(Count);
}

internal void
MacBuildAppPathFileName(mac_state *State, char *FileName,
						int DestCount, char *Dest)
{
	CatStrings(State->OnePastLastAppFileNameSlash - State->AppFileName, State->AppFileName,
			   StringLength(FileName), FileName,
			   DestCount, Dest);
}

DEBUG_PLATFORM_FREE_FILE_MEMORY(DEBUGPlatformFreeFileMemory)
{
    if(Memory)
    {
    	free(Memory);
    }
}

DEBUG_PLATFORM_READ_ENTIRE_FILE(DEBUGPlatformReadEntireFile)
{
    debug_read_file_result Result = {};
	
	char FullPath[MAC_MAX_FILENAME_SIZE];
	CatStrings(MacState.ResourcesDirectorySize, MacState.ResourcesDirectory,
			   StringLength(Filename), Filename,
			   sizeof(FullPath), FullPath);
	
    FILE *FileHandle = fopen(FullPath, "r");
    if(FileHandle != NULL)
    {
		fseek(FileHandle, 0, SEEK_END);
		int FileSize = ftell(FileHandle);
        if(FileSize)
        {
        	rewind(FileHandle);
        	Result.Contents = malloc(FileSize);
            if(Result.Contents)
            {
                uint32 BytesRead = fread(Result.Contents, 1, FileSize, FileHandle);
                if(FileSize == BytesRead)
                {
                    // NOTE(casey): File read successfully
                    Result.ContentsSize = FileSize;
                }
                else
                {                    
                    // TODO(casey): Logging
                    DEBUGPlatformFreeFileMemory(Thread, Result.Contents);
                    Result.Contents = 0;
                }
            }
            else
            {
                // TODO(casey): Logging
            }
        }
        else
        {
            // TODO(casey): Logging
        }

        fclose(FileHandle);
    }
    else
    {
        // TODO(casey): Logging
    }

    return(Result);
}

DEBUG_PLATFORM_WRITE_ENTIRE_FILE(DEBUGPlatformWriteEntireFile)
{
    bool32 Result = false;
    FILE *FileHandle = fopen(Filename, "w");
    if(FileHandle)
    {
        size_t BytesWritten = fwrite(Memory, 1, MemorySize, FileHandle);
        if(BytesWritten)
        {
            // NOTE(casey): File read successfully
            Result = (BytesWritten == MemorySize);
        }
        else
        {
            // TODO(casey): Logging
        }

        fclose(FileHandle);
    }
    else
    {
        // TODO(casey): Logging
    }

    return(Result);
}
inline time_t
MacGetLastWriteTime(char *Filename)
{
	time_t LastWriteTime = 0;
	
	struct stat StatData = {};

    if (stat(Filename, &StatData) == 0)
    {
        LastWriteTime = StatData.st_mtime;
    }

    return(LastWriteTime);
}

internal mac_game_code
MacLoadGameCode(char *SourceDLLName)
{
    mac_game_code Result = {};
    
    Result.DLLLastWriteTime = MacGetLastWriteTime(SourceDLLName);
    
    Result.GameCodeDLL = dlopen(SourceDLLName, RTLD_NOW);
    if (Result.GameCodeDLL)
    {
        Result.UpdateAndRender = (game_update_and_render *)
            dlsym(Result.GameCodeDLL, "GameUpdateAndRender");
        
        Result.GetSoundSamples = (game_get_sound_samples *)
            dlsym(Result.GameCodeDLL, "GameGetSoundSamples");

        Result.IsValid = (Result.UpdateAndRender &&
                          Result.GetSoundSamples);
    }
    if(!Result.IsValid)
    {
        Result.UpdateAndRender = 0;
        Result.GetSoundSamples = 0;
    }

    return(Result);
}


internal void
MacUnloadGameCode(mac_game_code *GameCode)
{
    if(GameCode->GameCodeDLL)
    {
    	dlclose(GameCode->GameCodeDLL);
        GameCode->GameCodeDLL = 0;
    }

    GameCode->IsValid = false;
    GameCode->UpdateAndRender = 0;
    GameCode->GetSoundSamples = 0;
}


void MacAudioQueueOutputCallback (void *inUserData, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
	NSLog(@"Callback");
	
	mac_sound_output *SoundOutput = (mac_sound_output *)inUserData;
	
// 	int16 *SourceSample = (int16 *)GlobalSecondaryBuffer;
// 	int16 *DestSample = (int16 *)buffer->mUserData;
// 	if (SourceSample) {
// 		for(uint32 SampleIndex = 0;
// 			SampleIndex < SoundOutput->SecondaryBufferSize;
// 			++SampleIndex)
// 		{
// 			*DestSample++ = *SourceSample++;
// 			++SoundOutput->RunningSampleIndex;
// 		}
// 	}
//	buffer->mAudioDataByteSize = SoundOutput->SecondaryBufferSize;
    uint32_t framesToGen = buffer->mAudioDataBytesCapacity / 4;
    buffer->mAudioDataByteSize = framesToGen * 4;
	AudioQueueEnqueueBuffer(queue, buffer, 0, 0);
}
internal void
MacInitSound(mac_sound_output *SoundOutput, int32 SamplesPerSecond, int32 BufferSize)
{
	AudioStreamBasicDescription StreamDescription = { 0 };
	StreamDescription.mSampleRate = SamplesPerSecond;
	StreamDescription.mFormatID = kAudioFormatLinearPCM;
	StreamDescription.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	StreamDescription.mBytesPerPacket = 4;
	StreamDescription.mFramesPerPacket = 1;
	StreamDescription.mBytesPerFrame = 4;
	StreamDescription.mChannelsPerFrame = 2;
	StreamDescription.mBitsPerChannel = 16;
	
	OSStatus QueueStatus = AudioQueueNewOutput (&StreamDescription, MacAudioQueueOutputCallback, SoundOutput, 0, 0, 0, &SoundOutput->Queue);
	if (QueueStatus == kAudioFormatUnsupportedDataFormatError) {
		NSLog(@"OOPS");
		Assert(0);
	}
	AudioQueueSetParameter(SoundOutput->Queue, kAudioQueueParam_Volume, 0.005);
	
	for (uint32 i = 0; 
		 i < ArrayCount(SoundOutput->Buffers);
		 i++) {
		QueueStatus = AudioQueueAllocateBuffer (SoundOutput->Queue, BufferSize, &SoundOutput->Buffers[i]);
		
		// TODO (Mike): We may not need to prime buffers the first time through. 
		// What is it playing if we do? We have no sound yet.
		MacAudioQueueOutputCallback (&SoundOutput, SoundOutput->Queue, SoundOutput->Buffers[i]);
	}
	
	QueueStatus = AudioQueueStart (SoundOutput->Queue, NULL);
	printf ("Audio Queue Started: %d\n", QueueStatus);
}

internal void
MacClearBuffer(mac_sound_output *SoundOutput)
{
	uint16 *DestSample = (uint16 *)GlobalSecondaryBuffer;
	for(uint32 ByteIndex = 0;
		ByteIndex < SoundOutput->BytesPerSample;
		++ByteIndex)
	{
		*DestSample++ = 0;
	}
}

internal void
MacFillSoundBuffer(mac_sound_output *SoundOutput, uint32 ByteToLock, uint32 BytesToWrite,
                     game_sound_output_buffer *SourceBuffer)
{
	int16 *DestSample = (int16 *)GlobalSecondaryBuffer;
	int16 *SourceSample = SourceBuffer->Samples;
	for(uint32 SampleIndex = 0;
		SampleIndex < BytesToWrite;
		++SampleIndex)
	{
		*DestSample++ = *SourceSample++;
		++SoundOutput->RunningSampleIndex;
	}
}


internal void
MacProcessKeyboardMessage(game_button_state *NewState, bool32 IsDown)
{
    //Assert(NewState->EndedDown != IsDown);
	if (NewState->EndedDown != IsDown)
	{
		NewState->EndedDown = IsDown;
		++NewState->HalfTransitionCount;
	}
}

internal void
MacProcessPendingMessages(game_controller_input *KeyboardController)
{
	NSEvent *event;
	do
	{
		event = [NSApp nextEventMatchingMask:NSAnyEventMask
								   untilDate:nil
									  inMode:NSDefaultRunLoopMode
									 dequeue:YES];
		switch(event.type)
		{
			case NSKeyDown:
			case NSKeyUp:
			{
				bool32 WasDown = (event.isARepeat == YES);
				bool32 IsDown = (event.type == NSKeyDown);
				if (event.keyCode == HHWKey) {
					MacProcessKeyboardMessage(&KeyboardController->MoveUp, IsDown);
				} else if (event.keyCode == HHAKey) {
					MacProcessKeyboardMessage(&KeyboardController->MoveLeft, IsDown);
				} else if (event.keyCode == HHSKey) {
					MacProcessKeyboardMessage(&KeyboardController->MoveDown, IsDown);
				} else if (event.keyCode == HHDKey) {
					MacProcessKeyboardMessage(&KeyboardController->MoveRight, IsDown);
				} else if (event.keyCode == HHQKey) {
					if (([event modifierFlags] & NSCommandKeyMask)) {
						[NSApp sendEvent:event];
						[NSApp updateWindows];
					} else {
						MacProcessKeyboardMessage(&KeyboardController->LeftShoulder, IsDown);
					}
				} else if (event.keyCode == HHEKey) {
					MacProcessKeyboardMessage(&KeyboardController->RightShoulder, IsDown);
				} else if (event.keyCode == HHPKey) {
					if (IsDown && !WasDown) {
						GlobalPause = !GlobalPause;
					}
				} else if (event.keyCode == HHLKey) {
					NSLog(@"SaveGameState");
				} else if (event.keyCode == HHUpKey) {
					MacProcessKeyboardMessage(&KeyboardController->ActionUp, IsDown);
				} else if (event.keyCode == HHLeftKey) {
					MacProcessKeyboardMessage(&KeyboardController->ActionLeft, IsDown);
				} else if (event.keyCode == HHDownKey) {
					MacProcessKeyboardMessage(&KeyboardController->ActionDown, IsDown);
				} else if (event.keyCode == HHRightKey) {
					MacProcessKeyboardMessage(&KeyboardController->ActionRight, IsDown);
				} else if (event.keyCode == HHEscKey) {
					MacProcessKeyboardMessage(&KeyboardController->Start, IsDown);
				} else if (event.keyCode == HHSpaceKey) {
					MacProcessKeyboardMessage(&KeyboardController->Back, IsDown);
				} else {
					NSLog(@"KeyCode: %d", event.keyCode);
				}
			} break;
			default:
			{
				[NSApp sendEvent:event];
				[NSApp updateWindows];
			} break;
		}
	} while (event != nil);
}

inline real32
MacGetSecondsElapsed(uint64 Start, uint64 End)
{
	uint64 elapsed = (End - Start);
    real32 Result = (real32)(elapsed * (GlobalPerfCountFrequency.numer / GlobalPerfCountFrequency.denom)) / 1000.f / 1000.f / 1000.f;
    return(Result);
}

internal void
MacResizeBuffer(mac_offscreen_buffer *Buffer, int Width, int Height)
{
	int BytesPerPixel = 4;
    Buffer->BytesPerPixel = BytesPerPixel;
    
	if (Buffer->Memory) {
		free(Buffer->Memory);
	}
	Buffer->Width = Width;
	Buffer->Height = Height;
	Buffer->BytesPerPixel = BytesPerPixel;
	Buffer->Pitch = Width*BytesPerPixel;
	
	int BitmapMemorySize = (Buffer->Width*Buffer->Height)*BytesPerPixel;
	Buffer->Memory = malloc(BitmapMemorySize);
	Assert(Buffer->Memory);
}

internal mac_window_dimension
MacGetWindowDimension(NSWindow *Window)
{
	mac_window_dimension Result;
	
	Result.Height = [Window.contentView frame].size.height ;
	Result.Width = [Window.contentView frame].size.width;
	return(Result);
}

internal void
MacDisplayBufferInWindow(mac_offscreen_buffer *Buffer, CGContextRef DeviceContext,
						 int WindowWidth, int WindowHeight)
{
	
	CGRect rect = CGRectMake(0,(WindowHeight - Buffer->Height), Buffer->Width, Buffer->Height);
	
	size_t bitsPerComponent = 8;
	size_t bitsPerPixel = bitsPerComponent * 4;
	size_t BitmapMemorySize = (Buffer->Width * Buffer->Height * 4);
	
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGDataProviderRef provider = CGDataProviderCreateWithData (NULL, Buffer->Memory, BitmapMemorySize, 0);
	CGImageRef image = CGImageCreate(Buffer->Width, Buffer->Height, bitsPerComponent, bitsPerPixel,
									 Buffer->Pitch, space, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little, provider, 0, 0, kCGRenderingIntentDefault);
	
	CGContextDrawImage(DeviceContext, rect, image);
	CGContextFlush(DeviceContext);
	
	CGImageRelease(image);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(space);
}

int main(int argc, char** argv) {
	
	MacState = {};
	
	mach_timebase_info(&GlobalPerfCountFrequency);

    MacGetAppFileName(&MacState);

	char SourceGameCodeDLLFullPath[MAC_MAX_FILENAME_SIZE];
    MacBuildAppPathFileName(&MacState, "../Resources/GameCode.dylib",
                               sizeof(SourceGameCodeDLLFullPath), SourceGameCodeDLLFullPath);
	
	MacBuildAppPathFileName(&MacState, "../Resources/",
							sizeof(MacState.ResourcesDirectory), MacState.ResourcesDirectory);
	MacState.ResourcesDirectorySize = StringLength(MacState.ResourcesDirectory);
	
	// Set up application and window
	NSApplication *application = [NSApplication sharedApplication];
	[application setActivationPolicy:NSApplicationActivationPolicyRegular];
	
	NSMenu* menubar = [NSMenu new];
	
	NSMenuItem* appMenuItem = [NSMenuItem new];
	[menubar addItem:appMenuItem];
	
	[application setMainMenu:menubar];
	
	NSMenu* appMenu = [NSMenu new];
	NSString* appName = @"Handmade Hero";
	
	NSString* quitTitle = [@"Quit " stringByAppendingString:appName];
	NSMenuItem* quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle
    											 action:@selector(terminate:)
    									  keyEquivalent:@"q"];
	[appMenu addItem:quitMenuItem];
	[appMenuItem setSubmenu:appMenu];
	
	int WindowWidth = 960;
	int WindowHeight = 540;
	MacResizeBuffer(&GlobalBackbuffer, WindowWidth, WindowHeight);
	
	NSRect screenRect = [[NSScreen mainScreen] frame];
	NSRect frame = NSMakeRect((screenRect.size.width - (real32)WindowWidth) * 0.5,
							  (screenRect.size.height - (real32)WindowHeight) * 0.5,
							  (real32)WindowWidth,
							  (real32)WindowHeight);
	
	NSWindow* window  = [[NSWindow alloc] initWithContentRect:frame
													styleMask:NSResizableWindowMask|NSMiniaturizableWindowMask|NSClosableWindowMask|NSTitledWindowMask
													  backing:NSBackingStoreBuffered
														defer:NO];
	[window setMinSize:NSMakeSize(100, 100)];
	[window setTitle:@"HandmadeHero OSX"];
	[window makeKeyAndOrderFront:nil];
	[application finishLaunching];
	
    int MonitorRefreshHz = 60;
	real32 GameUpdateHz = (MonitorRefreshHz / 2.0f);
	real32 TargetSecondsPerFrame = 1.0f / (real32)GameUpdateHz;
	
	uint32 BytesToWrite = 16;
	
	// our persistent state for sound playback
	mac_sound_output SoundOutput = {};
	// TODO(casey): Make this like sixty seconds?
	SoundOutput.SamplesPerSecond = 48000;
	SoundOutput.BytesPerSample = sizeof(int16)*2;
	SoundOutput.SecondaryBufferSize = SoundOutput.SamplesPerSecond*SoundOutput.BytesPerSample;
	// TODO(casey): Actually compute this variance and see
	// what the lowest reasonable value is.
	SoundOutput.SafetyBytes = (int)(((real32)SoundOutput.SamplesPerSecond*(real32)SoundOutput.BytesPerSample / GameUpdateHz)/3.0f);
	
	GlobalSecondaryBuffer = malloc(SoundOutput.SecondaryBufferSize);
    Assert(GlobalSecondaryBuffer != MAP_FAILED);
	
	//MacInitSound(&SoundOutput, SoundOutput.SamplesPerSecond, SoundOutput.SecondaryBufferSize);
	
	GlobalRunning = YES;

#if 0
            // NOTE(casey): This tests the PlayCursor/WriteCursor update frequency
            // On the Handmade Hero machine, it was 480 samples.
            while(GlobalRunning)
            {
                uint32 PlayCursor;
                uint32 WriteCursor;
                GlobalSecondaryBuffer->GetCurrentPosition(&PlayCursor, &WriteCursor);

                char TextBuffer[256];
                _snprintf_s(TextBuffer, sizeof(TextBuffer),
                            "PC:%u WC:%u\n", PlayCursor, WriteCursor);
                OutputDebugStringA(TextBuffer);
            }
#endif
	
	// Allocate Memory
	game_memory GameMemory = {};
	GameMemory.PermanentStorageSize = Megabytes(64);
	GameMemory.TransientStorageSize = Gigabytes(1);
	GameMemory.DEBUGPlatformFreeFileMemory = DEBUGPlatformFreeFileMemory;
	GameMemory.DEBUGPlatformReadEntireFile = DEBUGPlatformReadEntireFile;
	GameMemory.DEBUGPlatformWriteEntireFile = DEBUGPlatformWriteEntireFile;
	
	uint64 totalSize = GameMemory.PermanentStorageSize + GameMemory.TransientStorageSize;
#if HANDMADE_INTERNAL
	char *BaseAddress = (char *)Terabytes(2);
	GameMemory.PermanentStorage = mmap(BaseAddress, totalSize,
									   PROT_READ|PROT_WRITE,
									   MAP_PRIVATE|MAP_FIXED|MAP_ANON,
									   -1, 0);
	Assert(GameMemory.PermanentStorage != MAP_FAILED);
#else
	char *BaseAddress = malloc(totalSize);
#endif
	
	GameMemory.TransientStorage = ((uint8*)GameMemory.PermanentStorage
								   + GameMemory.PermanentStorageSize);
	
 	for(int ReplayIndex = 0;
 		ReplayIndex < ArrayCount(MacState.ReplayBuffers);
 		++ReplayIndex)
 	{
// 		mac_replay_buffer *ReplayBuffer = &MacState.ReplayBuffers[ReplayIndex];
// 
// 		// TODO(casey): Recording system still seems to take too long
// 		// on record start - find out what Windows is doing and if
// 		// we can speed up / defer some of that processing.
// 		
// 		MacGetInputFileLocation(&MacState, false, ReplayIndex,
// 								  sizeof(ReplayBuffer->FileName), ReplayBuffer->FileName);
// 
// 		ReplayBuffer->FileHandle = FILE *FileHandle = fopen(ReplayBuffer->FileName, "w+");
// 
// 		uint64 MaxSize;
// 		MaxSize = Win32State.TotalSize;
// 		ReplayBuffer->MemoryMap = CreateFileMapping(
// 			ReplayBuffer->FileHandle, 0, PAGE_READWRITE,
// 			MaxSize., MaxSize.LowPart, 0);
// 
// 		ReplayBuffer->MemoryBlock = MapViewOfFile(
// 			ReplayBuffer->MemoryMap, FILE_MAP_ALL_ACCESS, 0, 0, Win32State.TotalSize);
// 		if(ReplayBuffer->MemoryBlock)
// 		{
// 		}
// 		else
// 		{
// 			// TODO(casey): Diagnostic
// 		}
 	}
	
	
	if(!(GameMemory.PermanentStorage && GameMemory.TransientStorage))
	{
		NSLog(@"Memory not allocated correctly");
		return 0;
	}
	game_input Input[2] = {};
	game_input *NewInput = &Input[0];
	game_input *OldInput = &Input[1];
	
	uint64 LastCounter = mach_absolute_time();
	uint64 FlipWallClock = mach_absolute_time();

	int DebugTimeMarkerIndex = 0;
	mac_debug_time_marker DebugTimeMarkers[30] = {{0}};

	uint32 AudioLatencyBytes = 0;
	real32 AudioLatencySeconds = 0;
	bool32 SoundIsValid = false;

	mac_game_code Game = MacLoadGameCode(SourceGameCodeDLLFullPath);
	
	uint32 LoadCounter = 0;
	
	while (GlobalRunning && ([[application windows] count] > 0))
	{
		@autoreleasepool {
            NewInput->dtForFrame = TargetSecondsPerFrame;
                    
			time_t NewDLLWriteTime = MacGetLastWriteTime(SourceGameCodeDLLFullPath);
			if(NewDLLWriteTime != Game.DLLLastWriteTime)
			{
				MacUnloadGameCode(&Game);
				Game = MacLoadGameCode(SourceGameCodeDLLFullPath);
				LoadCounter = 0;
			}
            
			game_controller_input *OldKeyboardController = GetController(OldInput, 0);
			game_controller_input *NewKeyboardController = GetController(NewInput, 0);
			*NewKeyboardController = {};
			NewKeyboardController->IsConnected = true;
			
			for(int ButtonIndex = 0;
				ButtonIndex < ArrayCount(NewKeyboardController->Buttons);
				++ButtonIndex)
			{
				NewKeyboardController->Buttons[ButtonIndex].EndedDown =
				OldKeyboardController->Buttons[ButtonIndex].EndedDown;
			}
			
			for(int ButtonIndex = 0;
				ButtonIndex < ArrayCount(NewInput->MouseButtons);
				++ButtonIndex)
			{
				NewInput->MouseButtons[ButtonIndex].EndedDown =
				OldInput->MouseButtons[ButtonIndex].EndedDown;
			}
			NewInput->MouseX = OldInput->MouseX;
			NewInput->MouseY = OldInput->MouseY;
			NewInput->MouseZ = OldInput->MouseZ;
			
			MacProcessPendingMessages(NewKeyboardController);
			
			if(!GlobalPause)
			{
				{
					NSPoint MouseP = window.mouseLocationOutsideOfEventStream;
					Input->MouseX = MouseP.x;
					Input->MouseY = WindowHeight - MouseP.y;
					Input->MouseZ = 0;
					bool32 MouseDown = (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 0));
					MacProcessKeyboardMessage(&Input->MouseButtons[0],
						CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 0));
					MacProcessKeyboardMessage(&Input->MouseButtons[1],
						CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 1));
					MacProcessKeyboardMessage(&Input->MouseButtons[2],
						CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 2));
					MacProcessKeyboardMessage(&Input->MouseButtons[3],
						CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 3));
					MacProcessKeyboardMessage(&Input->MouseButtons[4],
						CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 4));
					// Handle Controllers
				}
			
				thread_context Thread = {};
				
				game_offscreen_buffer Buffer = {};
				Buffer.Memory = GlobalBackbuffer.Memory;
				Buffer.Width = GlobalBackbuffer.Width;
				Buffer.Height = GlobalBackbuffer.Height;
				Buffer.Pitch = GlobalBackbuffer.Pitch;
				Buffer.BytesPerPixel = GlobalBackbuffer.BytesPerPixel;

	 			if(MacState.InputRecordingIndex)
	 			{
	 				// MacRecordInput(&MacState, NewInput);
	 			}
	 			if(MacState.InputPlayingIndex)
	 			{
	 				// MacPlayBackInput(&MacState, NewInput);
	 			}

				if(Game.UpdateAndRender)
				{
					Game.UpdateAndRender(&Thread, &GameMemory, NewInput, &Buffer);
				}
				
				
				if(Game.GetSoundSamples){
					uint64 AudioWallClock = mach_absolute_time();
					real32 FromBeginToAudioSeconds = MacGetSecondsElapsed(FlipWallClock, AudioWallClock);
				
					/* Sound is still wrong. Poor Sound... */
					uint32 ByteToLock = ((SoundOutput.RunningSampleIndex*SoundOutput.BytesPerSample) %
										 SoundOutput.SecondaryBufferSize);
					
					game_sound_output_buffer SoundBuffer = {};
					SoundBuffer.SamplesPerSecond = SoundOutput.SamplesPerSecond;
					SoundBuffer.SampleCount = BytesToWrite / SoundOutput.BytesPerSample;
					SoundBuffer.Samples = (int16 *)GlobalSecondaryBuffer;
				
				
					Game.GetSoundSamples(&Thread, &GameMemory, &SoundBuffer);
				}
				uint64 WorkCounter = mach_absolute_time();
				real32 WorkSecondsElapsed = MacGetSecondsElapsed(LastCounter, WorkCounter);
				
				real32 SecondsElapsedForFrame = WorkSecondsElapsed;
				if(SecondsElapsedForFrame < TargetSecondsPerFrame)
				{
					useconds_t SleepMS = (useconds_t)(1000.0f * 1000.0f * (TargetSecondsPerFrame -
													   SecondsElapsedForFrame));
					if(SleepMS > 0)
					{
						usleep(SleepMS);
					}
				
					real32 TestSecondsElapsedForFrame = MacGetSecondsElapsed(LastCounter,
																			   mach_absolute_time());
					if(TestSecondsElapsedForFrame < TargetSecondsPerFrame)
					{
						// TODO(casey): LOG MISSED SLEEP HERE
					}
				
					while(SecondsElapsedForFrame < TargetSecondsPerFrame)
					{
						SecondsElapsedForFrame = MacGetSecondsElapsed(LastCounter,
																		mach_absolute_time());
					}
				}
				else
				{
					// TODO(casey): MISSED FRAME RATE!
					// TODO(casey): Logging
				}
				
				uint64 EndCounter = mach_absolute_time();
				real32 MSPerFrame = MacGetSecondsElapsed(LastCounter, EndCounter);                    
				LastCounter = EndCounter;
							
				mac_window_dimension Dimension = MacGetWindowDimension(window);
				CGContextRef DeviceContext = (CGContextRef)window.graphicsContext.graphicsPort;
				MacDisplayBufferInWindow(&GlobalBackbuffer, DeviceContext,
										 Dimension.Width, Dimension.Height);
				
				FlipWallClock = mach_absolute_time();
#if HANDMADE_INTERNAL
				{
				// NOTE(casey): This is debug code
// 					DWORD PlayCursor;
// 					DWORD WriteCursor;
// 					if(GlobalSecondaryBuffer->GetCurrentPosition(&PlayCursor, &WriteCursor) == DS_OK)
// 					{
// 						Assert(DebugTimeMarkerIndex < ArrayCount(DebugTimeMarkers));
// 						win32_debug_time_marker *Marker = &DebugTimeMarkers[DebugTimeMarkerIndex];
// 						Marker->FlipPlayCursor = PlayCursor;
// 						Marker->FlipWriteCursor = WriteCursor;
// 					}
				
				}
#endif
				
				game_input *Temp = NewInput;
				NewInput = OldInput;
				OldInput = Temp;
				
				
#if 0
			
				real64 FPS = 0.0f;

				NSLog(@"%.03fms/f,  %.02ff/s\n", MSPerFrame, FPS);
#endif
				
#if HANDMADE_INTERNAL
				++DebugTimeMarkerIndex;
				if(DebugTimeMarkerIndex == ArrayCount(DebugTimeMarkers))
				{
					DebugTimeMarkerIndex = 0;
				}
#endif
			}
		}
		
	}
	
	return 0;
}
