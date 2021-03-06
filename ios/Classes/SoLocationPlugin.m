#import "SoLocationPlugin.h"

NSString const *GRANTED = @"GRANTED";
NSString const *PERMISSION_DENIED = @"PERMISSION_DENIED";

NSDictionary<NSString*,NSNumber*>* locationToDict(CLLocation *location){
    NSTimeInterval timeInSeconds = [location.timestamp timeIntervalSince1970];
    NSDictionary<NSString*,NSNumber*>* coordinatesDict =
    @{
      @"latitude": @(location.coordinate.latitude),
      @"longitude": @(location.coordinate.longitude),
      @"accuracy": @(location.horizontalAccuracy),
      @"altitude": @(location.altitude),
      @"speed": @(location.speed),
      @"speed_accuracy": @0.0,
      @"heading": @(location.course),
      @"time": @(((double) timeInSeconds) * 1000.0)  // in milliseconds since the epoch
    };
    return coordinatesDict;
}

typedef void (^OnEnd)(OneTimeLocationResultHolder*, CLLocation*);

@interface OneTimeLocationResultHolder()
@property (strong, nonatomic) CLLocationManager *clLocationManager;
@property (strong, nonatomic) SoLocationPlugin *plugin;
@property (strong, nonatomic) NSMutableArray *results;
@property (strong, nonatomic) CLLocation *lastLocation;
@end

@implementation OneTimeLocationResultHolder

- (instancetype)initWithPlugin:(SoLocationPlugin*)plugin {
    self = [super init];
    self.clLocationManager=[[CLLocationManager alloc] init];
    self.clLocationManager.delegate = self;
    self.clLocationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.plugin=plugin;
    self.results=[NSMutableArray new];
    return self;
}



-(void)start:(FlutterResult)result {
    NSLog(@"started 0");
    [self.results addObject:[result copy]];
    [self.clLocationManager startUpdatingLocation];
    NSLog(@"started 1");
}

-(void)clear:(id _Nullable)result {
    NSLog(@"result 0");
    [self.clLocationManager stopUpdatingLocation];
    NSLog(@"result 1");
    NSArray *results=[[NSArray alloc] initWithArray:self.results];
    NSLog(@"result 2");
    [self.results removeObjectsInArray:results];
    NSLog(@"result 3");
    for (int i = 0; i < results.count; i++)
    {
        FlutterResult flutterResult = results[i];
        flutterResult(result);
    }
    NSLog(@"result 4");
}

-(void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray<CLLocation*>*)locations {
    CLLocation *location = locations.firstObject;
    if(location!=nil && self.lastLocation!=nil && [location.timestamp compare:self.lastLocation.timestamp]!=NSOrderedDescending){
        location=nil;
    }
    if(location!=nil){
        self.lastLocation=location;
        [self clear:locationToDict(location)];
        [self.plugin setLastLocation:location];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [self clear:[FlutterError errorWithCode:@"LOCATION_FAILED" message:nil details:nil]];
}

- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(nullable NSError *)error API_AVAILABLE(ios(6.0), macos(10.9)) API_UNAVAILABLE(watchos, tvos){
    [self clear:[FlutterError errorWithCode:@"LOCATION_FAILED" message:nil details:nil]];
}

@end

@interface SoLocationPlugin() <FlutterStreamHandler, CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *clLocationManager;
@property (copy, nonatomic)   FlutterResult      permissionResult;
@property (copy, nonatomic)   FlutterEventSink   flutterEventSink;
@property (strong, nonatomic) OneTimeLocationResultHolder *oneTimeLocationResultHolder;
@property (copy, nonatomic) CLLocation *_lastLocation;
@end

@implementation SoLocationPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"so_location/method" binaryMessenger:[registrar messenger]];
    FlutterEventChannel *stream = [FlutterEventChannel eventChannelWithName:@"so_location/stream" binaryMessenger:registrar.messenger];
    SoLocationPlugin* instance = [[SoLocationPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    [stream setStreamHandler:instance];
    instance.oneTimeLocationResultHolder=[[OneTimeLocationResultHolder alloc] initWithPlugin:instance];
    if ([CLLocationManager locationServicesEnabled]) {
        instance.clLocationManager = [[CLLocationManager alloc] init];
        instance.clLocationManager.delegate = instance;
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
    }else if([@"getLocation" isEqualToString:call.method]){
        [self getLocation:result];
    }else if([@"getLastKnownLocation" isEqualToString:call.method]){
        if(self._lastLocation!=nil){
            result(locationToDict(self._lastLocation));
        }else{
            result(nil);
        }
    }else if([@"startLocationUpdates" isEqualToString:call.method]){
        double distanceFilter = [call.arguments[@"distanceFilter"] doubleValue];
        if (distanceFilter == 0){
            distanceFilter = kCLDistanceFilterNone;
        }
        [self startLocationUpdates:distanceFilter];
    }else if([@"stopLocationUpdates" isEqualToString:call.method]){
        [self stopLocationUpdates];
    }else {
        result(FlutterMethodNotImplemented);
    }
}
-(FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.flutterEventSink = events;
    return nil;
}

-(FlutterError*)onCancelWithArguments:(id)arguments {
    return nil;
}

-(void) setLastLocation:(CLLocation *)lastLocation{
    self._lastLocation=lastLocation;
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

-(void) getLocation:(FlutterResult)result {
    if(self.clLocationManager == nil){
        return [self returnLocationServicesEnabledRequiredError:result];
    }
    if(![self isPermissionGranted]){
        result([FlutterError errorWithCode:@"PERMISSION_NOT_GRANTED" message:nil details:nil]);
        return;
    }
    [self.oneTimeLocationResultHolder start:result];
    NSLog(@"start new end");
}

-(void) startLocationUpdates:(CLLocationDistance)distanceFilter {
    self.clLocationManager.distanceFilter=distanceFilter;
    [self.clLocationManager startUpdatingLocation];
}
-(void) stopLocationUpdates {
    [self.clLocationManager stopUpdatingLocation];
}
#pragma mark - CLLocationManagerDelegate Methods

-(void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray<CLLocation*>*)locations {
    CLLocation *location = locations.firstObject;
    if(self._lastLocation!=nil){
        NSLog(@"lastLocation is not nil");
    }
    self._lastLocation=location;
    if(self.flutterEventSink!=nil){
        self.flutterEventSink(locationToDict(location));
    }
}

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
