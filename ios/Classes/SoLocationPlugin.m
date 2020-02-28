#import "SoLocationPlugin.h"

#ifdef COCOAPODS
@import CoreLocation;
#else
#import <CoreLocation/CoreLocation.h>
#endif

NSString const *GRANTED = @"GRANTED";
NSString const *PERMISSION_DENIED = @"PERMISSION_DENIED";

@interface SoLocationPlugin() <FlutterStreamHandler, CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *clLocationManager;
@property (copy, nonatomic)   FlutterResult      permissionResult;

@property (copy, nonatomic)   FlutterEventSink   flutterEventSink;
@property (assign, nonatomic) BOOL               flutterListening;
@property (assign, nonatomic) BOOL               hasInit;
@end

@implementation SoLocationPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"so_location/method" binaryMessenger:[registrar messenger]];
  FlutterEventChannel *stream = [FlutterEventChannel eventChannelWithName:@"so_location/stream" binaryMessenger:registrar.messenger];
  SoLocationPlugin* instance = [[SoLocationPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
  if ([CLLocationManager locationServicesEnabled]) {
        instance.clLocationManager = [[CLLocationManager alloc] init];
        instance.clLocationManager.delegate = self;
        instance.clLocationManager.desiredAccuracy = kCLLocationAccuracyBest;
  }
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  }else if([@"listEnabledProvider" isEqualToString:call.method]){
      result(@[@"iOS"]);
  }else if([@"hasPermission" isEqualToString:call.method]){
      result([NSNumber numberWithBool:[self isPermissionGranted]]);
  }else if([@"requestPermission" isEqualToString:call.method]){
      if([self isPermissionGranted]){
          result(GRANTED);
      }else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
          [self requestPermission:result];
      } else {
          result(PERMISSION_DENIED);
      }
  }
  else {
    result(FlutterMethodNotImplemented);
  }
}

-(BOOL) isPermissionGranted {
    BOOL isPermissionGranted = NO;
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways:
            // Location services are available
            isPermissionGranted = YES;
            break;
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            // Location services are requested but user has denied / the app is restricted from
            // getting location
            isPermissionGranted = NO;
            break;
        case kCLAuthorizationStatusNotDetermined:
            // Location services never requested / the user still haven't decide
            isPermissionGranted = NO;
            break;
        default:
            isPermissionGranted = NO;
            break;
    }

    return isPermissionGranted;
}

-(void) returnLocationServicesEnabledRequiredError:(FlutterResult)result {
    result([FlutterError errorWithCode:@"LOCATION_SERVICE_DISABLED" message:nil details:nil]);
}

-(void) requestPermission:(FlutterResult)result {
    if(self.clLocationManager == nil){
        return [self returnLocationServicesEnabledRequiredError:result];
    }
    self.permissionResult=result;
    if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil) {
        [self.clLocationManager requestWhenInUseAuthorization];
    }
    else if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] != nil) {
        [self.clLocationManager requestAlwaysAuthorization];
    }
    else {
        result([FlutterError errorWithCode:@"LOCATION_SERVICE_NOT_SETUP" message:@"NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription should set in Info.plist" details:nil]);
    }
}

#pragma mark - CLLocationManagerDelegate Methods

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusDenied) {
        // The user denied authorization
        NSLog(@"User denied permissions");
        if(self.permissionResult != nil){
            self.permissionResult(PERMISSION_DENIED);
            self.permissionResult=nil;
        }
    }
    else if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        NSLog(@"User granted permissions");
        if(self.permissionResult != nil){
            self.permissionResult(PERMISSION_DENIED);
            self.permissionResult=nil;
        }
    }
}
@end
