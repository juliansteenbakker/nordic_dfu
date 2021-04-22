#import "NordicDfuPlugin.h"
#if __has_include(<nordic_dfu/nordic_dfu-Swift.h>)
#import <nordic_dfu/nordic_dfu-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "nordic_dfu-Swift.h"
#endif

@implementation NordicDfuPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftNordicDfuPlugin registerWithRegistrar:registrar];
}
@end
