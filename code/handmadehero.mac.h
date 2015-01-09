#if !defined(MAC_HANDMADE_H)
struct mac_offscreen_buffer
{
    // NOTE(casey): Pixels are alwasy 32-bits wide, Memory Order BB GG RR XX
    void *Memory;
    int Width;
    int Height;
    int Pitch;
    int BytesPerPixel;
};

struct mac_window_dimension
{
    int Width;
    int Height;
};

struct mac_sound_output
{
    int SamplesPerSecond;
    uint32 RunningSampleIndex;
    int BytesPerSample;
	uint32 SecondaryBufferSize;
	uint32 SafetyBytes;
    real32 tSine;
    int LatencySampleCount;
    AudioQueueBufferRef Buffers[2];
	AudioQueueRef Queue;
};

struct mac_debug_time_marker
{
    uint32 OutputPlayCursor;
    uint32 OutputWriteCursor;
    uint32 OutputLocation;
    uint32 OutputByteCount;
    uint32 ExpectedFlipPlayCursor;

    uint32 FlipPlayCursor;
    uint32 FlipWriteCursor;
};

struct mac_game_code
{
    void *GameCodeDLL;
    time_t DLLLastWriteTime;

    // IMPORTANT(casey): Either of the callbacks can be 0!  You must
    // check before calling.
    game_update_and_render *UpdateAndRender;
    game_get_sound_samples *GetSoundSamples;

    bool32 IsValid;
};

#define MAC_MAX_FILENAME_SIZE 4096
struct mac_replay_buffer
{
    FILE *FileHandle;
    FILE *MemoryMap;
    char FileName[MAC_MAX_FILENAME_SIZE];
    void *MemoryBlock;
};
struct mac_state
{
    uint64 TotalSize;
    void *GameMemoryBlock;
    mac_replay_buffer ReplayBuffers[4];
    
    FILE *RecordingHandle;
    int InputRecordingIndex;

    FILE *PlaybackHandle;
	int InputPlayingIndex;
	
	char ResourcesDirectory[MAC_MAX_FILENAME_SIZE];
	int ResourcesDirectorySize;
	
    char AppFileName[MAC_MAX_FILENAME_SIZE];
    char *OnePastLastAppFileNameSlash;
};


enum keyCodes
{
	HHAKey = 0,
	HHSKey = 1,
	HHDKey = 2,
	HHQKey = 12,
	HHWKey = 13,
	HHEKey = 14,
	HHPKey = 35,
	HHReturnKey = 36,
	HHLKey = 37,
	HHSpaceKey = 49,
	HHEscKey = 53,
	HHLeftKey = 123,
	HHRightKey = 124,
	HHDownKey = 125,
	HHUpKey = 126
};

#define MAC_HANDMADE_H
#endif