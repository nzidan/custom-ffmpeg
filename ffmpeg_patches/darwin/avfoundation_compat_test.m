#import <AVFoundation/AVFoundation.h>
#include <string.h>
#include "include/avfoundation_compat.h"

void find_device(const char *electron_name) {
  AVCaptureDevice *device = avdevice_compat_from_electron(electron_name);
  if (!device) {
    printf("=== Device not found ==== \n");
    return;
  }

  printf("==== AVDevice found ====\n");
  printf("AVDevice name: %s\n", [[device localizedName] UTF8String]);
  printf("AVDevice uuid: %s\n", [[device uniqueID] UTF8String]);
}


int main(int argc, char** argv)
{
  const char *name = "Line In (Built-in)";
  if (argc > 1) name = argv[1];
  printf("==== Looking for \"%s\" ====\n", name);
  find_device(name);

  return 0;
}

