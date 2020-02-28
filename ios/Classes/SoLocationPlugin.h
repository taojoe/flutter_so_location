#import <Flutter/Flutter.h>
#ifdef COCOAPODS
@import CoreLocation;
#else
#import <CoreLocation/CoreLocation.h>
#endif

@interface SoLocationPlugin : NSObject<FlutterPlugin>
@end

@interface OneTimeLocationResultHolder : NSObject<CLLocationManagerDelegate>
@end
