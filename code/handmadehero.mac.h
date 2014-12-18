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
};



enum keyCodes
{
	HHAKey = 0,
	HHSKey = 1,
	HHDKey = 2,
	HHQKey = 12,
	HHWKey = 13,
	HHEKey = 14,
	HHSpaceKey = 49,
	HHEscKey = 53,
	HHLeftKey = 123,
	HHRightKey = 124,
	HHDownKey = 125,
	HHUpKey = 126
};