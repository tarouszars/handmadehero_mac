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
#include <math.h>
#include <stdint.h>
#include <Cocoa/Cocoa.h>
#include "AudioToolbox/AudioToolbox.h"

#define internal static
#define local_persist static
#define global_variable static

#define Pi32 3.14159265359f


typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;
typedef int32 bool32;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

typedef float real32;
typedef double real64;


#include "handmade.h"
#include "handmade.cpp"

#include "handmadehero.mac.h"

global_variable BOOL GlobalRunning;
global_variable mac_offscreen_buffer GlobalBackbuffer;

internal debug_read_file_result
DEBUGPlatformReadEntireFile(char *Filename)
{
	debug_read_file_result Result = {};
	NSLog(@"%s", Filename);
	return(Result);
}

internal void
DEBUGPlatformFreeFileMemory(void *Memory)
{
	
}

internal bool32
DEBUGPlatformWriteEntireFile(char *Filename, uint32 MemorySize, void *Memory)
{
	bool32 Result = false;
	return Result;
}

internal void
MacResizeBuffer(mac_offscreen_buffer *Buffer, int Width, int Height)
{
	int BytesPerPixel = 4;
	if (Buffer->Memory) {
		uint64 totalSize = Buffer->Width * Buffer->Height * Buffer->BytesPerPixel;
		kern_return_t result = vm_deallocate((vm_map_t)mach_task_self(),
											 (vm_address_t)Buffer->Memory,
											 totalSize);
		Assert(result == KERN_SUCCESS);
	}
	Buffer->Width = Width;
	Buffer->Height = Height;
	Buffer->BytesPerPixel = BytesPerPixel;
	Buffer->Pitch = Width*BytesPerPixel;
	
	int BitmapMemorySize = (Buffer->Width*Buffer->Height)*BytesPerPixel;
	
	kern_return_t result = vm_allocate((vm_map_t)mach_task_self(),
									   (vm_address_t*)&Buffer->Memory,
									   BitmapMemorySize,
									   VM_FLAGS_ANYWHERE);
	Assert(result == KERN_SUCCESS);
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
	local_persist int lastScaleW = Buffer->Width;
	local_persist int lastScaleH = Buffer->Height;
	
	CGRect rect = CGRectMake(0,0, Buffer->Width,Buffer->Height);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	
	size_t bitsPerComponent = 8;
	size_t bitsPerPixel = bitsPerComponent * 4;
	size_t BitmapMemorySize = (Buffer->Width * Buffer->Height * 4);
	CGDataProviderRef provider = CGDataProviderCreateWithData (NULL, Buffer->Memory, BitmapMemorySize, 0);
	
	CGImageRef image = CGImageCreate(Buffer->Width, Buffer->Height, bitsPerComponent, bitsPerPixel,
									 Buffer->Pitch, space, kCGImageAlphaNoneSkipLast, provider, 0, 0, kCGRenderingIntentDefault);
	CGContextDrawImage(DeviceContext, rect, image);
	
	if (lastScaleW != WindowWidth ||
		lastScaleH != WindowHeight) {
		
		real32 WidthScale = (real32)WindowWidth / (real32)lastScaleW;
		real32 HeightScale = (real32)WindowHeight / (real32)lastScaleH;
		CGContextScaleCTM(DeviceContext, WidthScale, HeightScale);
	}
	lastScaleW = WindowWidth;
	lastScaleH = WindowHeight;
	CGImageRelease(image);
	CGContextFlush(DeviceContext);
}

typedef struct SoundState {
	float toneFreq, volume;
	float sampleRate, frameOffset;
	float squareWaveSign;
}SoundState;

void MyAudioQueueOutputCallback (void *inUserData, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
	uint32_t framesToGen = buffer->mAudioDataBytesCapacity / 4;
	buffer->mAudioDataByteSize = framesToGen * 4;
	AudioQueueEnqueueBuffer(queue, buffer, 0, 0);
}

int main(int argc, char** argv) {
	
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
	
	int WindowWidth = 1280;
	int WindowHeight = 720;
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
	
	// Setup Sound
	
	// To add playback functionality to your application, you typically perform the following steps:
	//
	// Define a custom structure to manage state, format, and path information.
	// Write an audio queue callback function to perform the actual playback.
	// Write code to determine a good size for the audio queue buffers.
	// Open an audio file for playback and determine its audio data format.
	// Create a playback audio queue and configure it for playback.
	// Allocate and enqueue audio queue buffers. Tell the audio queue to start playing. When done, the playback callback tells the audio queue to stop.
	// Dispose of the audio queue. Release resources.
	// The remainder of this chapter describes each of these steps in detail.
	//
	
#define MonitorRefreshHz 60
#define GameUpdateHz (MonitorRefreshHz / 2)
	
	uint32 BytesToWrite = 16;
	
	AudioQueueRef queue;
	
	AudioQueueBufferRef SoundBufferRef1 = {};
	AudioQueueBufferRef SoundBufferRef2 = {};
	
	// our persistent state for sound playback
	SoundState SoundOutput=  {};
	SoundOutput.toneFreq = 261.6 * 3; // 261.6 ~= Middle C frequency
	SoundOutput.volume = 0.1; // don't crank this up and expect your ears to still function
	SoundOutput.sampleRate = 48000.0f;
	SoundOutput.squareWaveSign = 1; // sign of the current part of the square wave
	
	AudioStreamBasicDescription StreamDescription = { 0 };
	StreamDescription.mSampleRate = SoundOutput.sampleRate;
	StreamDescription.mFormatID = kAudioFormatLinearPCM;
	StreamDescription.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	StreamDescription.mBytesPerPacket = 4;
	StreamDescription.mFramesPerPacket = 1;
	StreamDescription.mBytesPerFrame = 4;
	StreamDescription.mChannelsPerFrame = 2;
	StreamDescription.mBitsPerChannel = 16;
	
	OSStatus QueueStatus = AudioQueueNewOutput (&StreamDescription, MyAudioQueueOutputCallback, &SoundOutput, 0, 0, 0, &queue);
	if (QueueStatus == kAudioFormatUnsupportedDataFormatError) {
		NSLog(@"OOPS");
		Assert(0);
	}
	
	uint32_t bufferSize = StreamDescription.mBytesPerFrame * (StreamDescription.mSampleRate / 16);
	
	QueueStatus = AudioQueueAllocateBuffer (queue, bufferSize, &(SoundBufferRef1));
	QueueStatus = AudioQueueAllocateBuffer (queue, bufferSize, &(SoundBufferRef2));
	
	MyAudioQueueOutputCallback (&SoundOutput, queue, SoundBufferRef1);
	MyAudioQueueOutputCallback (&SoundOutput, queue, SoundBufferRef2);
	
	QueueStatus = AudioQueueStart (queue, NULL);
	printf ("Audio Queue Started: %d\n", QueueStatus);
	
	// 	int16 *Samples = (int16 *)buf_ref;
	// 	int16 *Samples2 = (int16 *)buf_ref2;
	//	int16 *Samples;
	//
	//	kern_return_t sound_result = vm_allocate((vm_map_t)mach_task_self(),
	//											 (vm_address_t*)&Samples,
	//											 SoundOutput.SecondaryBufferSize,
	//											 VM_FLAGS_ANYWHERE);
	//	Assert(sound_result == KERN_SUCCESS);
	
	// Allocate Memory
	game_memory GameMemory = {};
	GameMemory.PermanentStorageSize = Megabytes(64);
	GameMemory.TransientStorageSize = Gigabytes(1);
	
	uint64 totalSize = GameMemory.PermanentStorageSize + GameMemory.TransientStorageSize;
	kern_return_t result = vm_allocate((vm_map_t)mach_task_self(),
									   (vm_address_t*)&GameMemory.PermanentStorage,
									   totalSize,
									   VM_FLAGS_ANYWHERE);
	Assert(result == KERN_SUCCESS);
	
	GameMemory.TransientStorage = ((uint8*)GameMemory.PermanentStorage
								   + GameMemory.PermanentStorageSize);
	
	
	if(!(GameMemory.PermanentStorage && GameMemory.TransientStorage))
	{
		NSLog(@"Memory not allocated correctly");
		return 0;
	}
	game_input Input[2] = {};
	game_input *NewInput = &Input[0];
	game_input *OldInput = &Input[1];
	
	
	CGContextRef DeviceContext = (CGContextRef)[[window graphicsContext] graphicsPort];
	
	NSEvent *event;
	GlobalRunning = YES;
	while (GlobalRunning && ([[application windows] count] > 0))
	{
		@autoreleasepool {
			do
			{
				event = [NSApp nextEventMatchingMask:NSAnyEventMask
										   untilDate:nil
											  inMode:NSDefaultRunLoopMode
											 dequeue:YES];
				
				[NSApp sendEvent:event];
				[NSApp updateWindows];
			} while (event != nil);
			
			game_offscreen_buffer Buffer = {};
			Buffer.Memory = GlobalBackbuffer.Memory;
			Buffer.Width = GlobalBackbuffer.Width;
			Buffer.Height = GlobalBackbuffer.Height;
			Buffer.Pitch = GlobalBackbuffer.Pitch;
			GameUpdateAndRender(&GameMemory, Input, &Buffer);
			
			// 			uint32 ByteToLock = ((SoundOutput.RunningSampleIndex*SoundOutput.BytesPerSample) %
			// 								 SoundOutput.SecondaryBufferSize);
			game_sound_output_buffer GameSoundBufferA = {};
			GameSoundBufferA.SamplesPerSecond = SoundOutput.sampleRate;
			GameSoundBufferA.SampleCount = SoundBufferRef1->mAudioDataBytesCapacity / 4;
			GameSoundBufferA.Samples = (int16*)(SoundBufferRef1->mAudioData);
			SoundBufferRef1->mAudioDataByteSize = GameSoundBufferA.SampleCount * 4;
			
			game_sound_output_buffer GameSoundBufferB = {};
			GameSoundBufferB.SamplesPerSecond = SoundOutput.sampleRate;
			GameSoundBufferB.SampleCount = SoundBufferRef2->mAudioDataBytesCapacity / 4;
			GameSoundBufferB.Samples = (int16*)SoundBufferRef2->mAudioData;
			SoundBufferRef2->mAudioDataByteSize = GameSoundBufferB.SampleCount * 4;
			
			//GameOutputSound(&GameSoundBufferA, SoundOutput.toneFreq);
			//GameOutputSound(&GameSoundBufferB, SoundOutput.toneFreq);
			GameGetSoundSamples(&GameMemory, &GameSoundBufferA);
			GameGetSoundSamples(&GameMemory, &GameSoundBufferB);
			
			
			mac_window_dimension Dimension = MacGetWindowDimension(window);
			MacDisplayBufferInWindow(&GlobalBackbuffer, DeviceContext,
									 Dimension.Width, Dimension.Height);
		}
		
	}
	
	return 0;
}
