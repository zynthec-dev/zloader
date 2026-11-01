#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Launches an installed bundle without delivering a URL to its app delegate.
@interface ZLoaderAppLauncher : NSObject
+ (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
                        completionHandler:(void (^)(BOOL success, NSError * _Nullable error))completionHandler;
/// Uses only the app-specific zloader-<bundle ID> scheme if native launch fails.
+ (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
                       registeredLaunchURL:(nullable NSURL *)launchURL
                        completionHandler:(void (^)(BOOL success, NSError * _Nullable error))completionHandler;
@end

NS_ASSUME_NONNULL_END
