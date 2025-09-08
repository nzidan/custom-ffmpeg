#import <Foundation/Foundation.h>
#include <string.h>

#include "avfoundation_compat.h"

// ====== Utility ========

static inline int is_failed(OSStatus status) {
    if (status == noErr) return 0;

    NSString *error = [NSString stringWithFormat:@"Error %d", status];
    fprintf(stderr, "%s\n", [error UTF8String]);
    return 1;
}

static const char* transport2str(UInt32 transport_type) {
  switch (transport_type) {
    case kAudioDeviceTransportTypeBuiltIn:
      return "Built-in";
    case kAudioDeviceTransportTypeAggregate:
      return "Aggregate";
    case kAudioDeviceTransportTypeAutoAggregate:
      return "AutoAggregate";
    case kAudioDeviceTransportTypeVirtual:
      return "Virtual";
    case kAudioDeviceTransportTypePCI:
      return "PCI";
    case kAudioDeviceTransportTypeUSB:
      return "USB";
    case kAudioDeviceTransportTypeFireWire:
      return "FireWire";
    case kAudioDeviceTransportTypeBluetooth:
      return "Bluetooth";
    case kAudioDeviceTransportTypeBluetoothLE:
      return "Bluetooth LE";
    case kAudioDeviceTransportTypeHDMI:
      return "HDMI";
    case kAudioDeviceTransportTypeDisplayPort:
      return "DisplayPort";
    case kAudioDeviceTransportTypeAirPlay:
      return "AirPlay";
    case kAudioDeviceTransportTypeAVB:
      return "AVB";
    case kAudioDeviceTransportTypeThunderbolt:
      return "Thunderbolt";
    case kAudioDeviceTransportTypeUnknown:
    default:
      return NULL;
  }
}

// ====== AudioObject props ========

static inline AudioObjectPropertyAddress mk_audio_addr(AudioObjectPropertySelector selector, AudioObjectPropertyScope scope) {
    AudioObjectPropertyAddress address = {
        selector,
        scope,
        kAudioObjectPropertyElementMaster,
    };

    return address;
}

static NSString *get_str(AudioDeviceID device, AudioObjectPropertySelector selector) {
    AudioObjectPropertyAddress address = mk_audio_addr(selector, kAudioObjectPropertyScopeGlobal);
    CFStringRef prop;
    UInt32 propSize = sizeof(prop);
    OSStatus status = AudioObjectGetPropertyData(device, &address, 0,
                                                NULL, &propSize, &prop);
    if (is_failed(status)) return NULL;
    return (NSString *)prop;
}

static UInt32 get_u32(AudioDeviceID device, AudioObjectPropertySelector selector, AudioObjectPropertyScope scope) {
    AudioObjectPropertyAddress address = mk_audio_addr(selector, scope);
    UInt32 prop;
    UInt32 propSize = sizeof(prop);
    OSStatus status = AudioObjectGetPropertyData(device, &address, 0,
                                                 NULL, &propSize, &prop);
    if (is_failed(status)) return 0;
    return prop;
}

// ====== AudioObject data fetch ========

static NSMutableData* get_audio_ids(AudioObjectID audio_object_id, AudioObjectPropertySelector selector) {
    AudioObjectPropertyAddress property_address = mk_audio_addr(selector, kAudioObjectPropertyScopeInput);

    UInt32 size = 0;
    OSStatus result = AudioObjectGetPropertyDataSize(audio_object_id, &property_address, 0,
                                                    NULL, &size);  
    if (is_failed(result)) return NULL;
    if (size == 0) return NULL;

    NSMutableData* device_ids = [NSMutableData dataWithLength:size];
    AudioObjectID *devices = [device_ids mutableBytes];  
    result = AudioObjectGetPropertyData(audio_object_id, &property_address, 0,
                                        NULL, &size, devices); 
    if (is_failed(result)) return NULL;
    return device_ids;
}

static NSString* get_device_name(AudioObjectID device) {
    return get_str(device, kAudioObjectPropertyName);
}

static NSString* get_device_uuid(AudioObjectID device) {
    return get_str(device, kAudioDevicePropertyDeviceUID);
}

static NSString* get_device_source_name(AudioObjectID device) { 
    UInt32 source = get_u32(device, kAudioDevicePropertyDataSource, kAudioObjectPropertyScopeInput);
    if (!source) return NULL;

    CFStringRef source_name = NULL;
    AudioValueTranslation translation;
    translation.mInputData = &source;
    translation.mInputDataSize = sizeof(source);
    translation.mOutputData = &source_name;
    translation.mOutputDataSize = sizeof(source_name);

    UInt32 translation_size = sizeof(AudioValueTranslation);
    AudioObjectPropertyAddress property_address = {
        kAudioDevicePropertyDataSourceNameForIDCFString,
        kAudioObjectPropertyScopeInput, kAudioObjectPropertyElementMaster
    };

    OSStatus result = AudioObjectGetPropertyData(device, &property_address, 0,
                                                NULL, &translation_size, &translation);
    if (is_failed(result)) return NULL;
    return (NSString *)source_name;
}

static NSString* get_device_suffix(AudioObjectID device) {
    UInt32 type = get_u32(device, kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal);
    if (!type) return NULL;
    if (type != kAudioDeviceTransportTypeUSB) return [NSString stringWithUTF8String:transport2str(type)];

    NSString* model = get_str(device, kAudioDevicePropertyModelUID);
    if (!model) return NULL;

    size_t length = [model length];
    int has_vid = length > 10 && [model characterAtIndex:length-5] == ':' && [model characterAtIndex:length-10] == ':';
    if (!has_vid) return NULL;

    NSString* vid = [[model substringFromIndex:length-9] lowercaseString];
    return vid;
}

// ======  Device ========
static void device_fill_electron(Device *device) {
    NSString *label = device->source;
    if (!label) {
        label = device->name;
        if (!label) return;
    }
    
    if (!device->suffix) {
        device->electron_name = label;
        return;
    }

    NSString *final = [NSString stringWithFormat:@"%@ (%@)", label, device->suffix];
    device->electron_name = final;
}

static void device_init(Device *device) {
    if (device->inited) return;
    
    device->uuid = get_device_uuid(device->id);
    device->name = get_device_name(device->id);
    device->source = get_device_source_name(device->id);
    device->suffix = get_device_suffix(device->id);
    device_fill_electron(device);

    device->inited = 1;
}

static void device_create(Device *device, AudioObjectID id) {
    device->id = id;
    device->inited = 0;
}

static void device_print_list(NSMutableData *devices) {
    size_t device_count = [devices length] / sizeof(Device);
    if (device_count == 0) {
        fprintf(stderr, "No devices\n");
        return;
    }

    Device* devs_arr = [devices mutableBytes];
    for (size_t i = 0; i < device_count; ++i) {
        Device *device = &devs_arr[i];
        if (!device->inited) device_init(device);
    
        fprintf(stderr, "UUID: %s\n", [device->uuid UTF8String]);
        fprintf(stderr, "Name: %s\n", [device->name UTF8String]);
        fprintf(stderr, "Source: %s\n", [device->source UTF8String]);
        fprintf(stderr, "Suffix: %s\n", [device->suffix UTF8String]);
        fprintf(stderr, "Electron label: %s\n", [device->electron_name UTF8String]);
        if (i < device_count - 1) fprintf(stderr, "====\n");
    }
}
 
// ======  Public API ========

NSMutableData *avdevice_compat_alloc() {
    NSMutableData* ids = get_audio_ids(kAudioObjectSystemObject, kAudioHardwarePropertyDevices);
    size_t device_count = [ids length] / sizeof(AudioObjectID);
    if (device_count == 0) return NULL;

    NSMutableData* devices = [NSMutableData dataWithLength:sizeof(Device) * device_count];
    const AudioObjectID *ids_arr = [ids bytes];
    Device *devs_arr = [devices mutableBytes];
    for (size_t i = 0; i < device_count; ++i) {
        device_create(&devs_arr[i], ids_arr[i]);
    }

    return devices;
}


void avdevice_compat_free(NSMutableData *devices) {
    /* Auto release */
}

const Device* avdevice_compat_from_name(NSMutableData *devices, const char *src) {
    size_t device_count = [devices length] / sizeof(Device);
    if (device_count == 0) return NULL;

    Device* devs_arr = [devices mutableBytes];
    for (size_t i = 0; i < device_count; ++i) {
        Device *device = &devs_arr[i];
        if (!device->inited) device_init(device);
        if (strcmp([device->electron_name UTF8String], src) == 0) return device;
    }

    return NULL;
}


AVCaptureDevice* avdevice_compat_from_electron(const char *electron_name) {
    NSMutableData* devices = avdevice_compat_alloc();
    const Device *device = avdevice_compat_from_name(devices, electron_name);
    if (!device) {
        device_print_list(devices);
        avdevice_compat_free(devices);
        return NULL;
    }

    AVCaptureDevice *avdevice = [AVCaptureDevice deviceWithUniqueID:device->uuid];
    if (!avdevice) {
        fprintf(stderr, "Found device with %s uuid\nBut no corresponding AVDevice\n", [device->uuid UTF8String]);
        device_print_list(devices);
        avdevice_compat_free(devices);
        return NULL;
    }

    return avdevice;
}