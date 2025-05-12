#import <Flutter/Flutter.h>

@interface FlutterBackgroundServicePlugin : NSObject
+ (void)setPluginRegistrantCallback:(void(^)(NSObject<FlutterPluginRegistry>*))callback;
+ (void)performFetch:(void(^)(UIBackgroundFetchResult))completionHandler;
@end

// Implementación que redirige al AppDelegate
@implementation FlutterBackgroundServicePlugin

+ (void)setPluginRegistrantCallback:(void(^)(NSObject<FlutterPluginRegistry>*))callback {
    // Redirigir a AppDelegate (esta implementación será reemplazada por Swift)
    NSLog(@"FlutterBackgroundServicePlugin setPluginRegistrantCallback llamado");
}

+ (void)performFetch:(void(^)(UIBackgroundFetchResult))completionHandler {
    // Redirigir a AppDelegate (esta implementación será reemplazada por Swift)
    NSLog(@"FlutterBackgroundServicePlugin performFetch llamado");
    completionHandler(UIBackgroundFetchResultNewData);
}

@end 