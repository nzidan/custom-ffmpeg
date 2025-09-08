#ifndef HAAL_CHROMIUM_COMPAT_H
#define HAAL_CHROMIUM_COMPAT_H
#import <AVFoundation/AVFoundation.h>

// Check chromium and ffmpeg sources for more details
// https://github.com/FFmpeg/FFmpeg/blob/master/libavdevice/avfoundation.m#L765-L791
// https://source.chromium.org/chromium/chromium/src/+/master:media/audio/mac/core_audio_util_mac.cc;l=89-124

struct Device {
    AudioObjectID id;
    NSString *uuid;
    NSString *name;
    NSString *source;
    NSString *suffix;
    NSString *electron_name;

    int inited;
};
typedef struct Device Device;

NSMutableData* avdevice_compat_alloc(void);
void avdevice_compat_free(NSMutableData *devices);

const struct Device* avdevice_compat_from_name(NSMutableData *devices, const char *src);

int avdevice_compat_is_same(NSMutableData *devices, AVCaptureDevice *device);
int avdevice_compat_is_same_raw(NSMutableData *devices, const char *dest);

AVCaptureDevice* avdevice_compat_from_electron(const char *electron_name);

#endif