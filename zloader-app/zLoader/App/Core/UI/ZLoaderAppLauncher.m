#import "ZLoaderAppLauncher.h"
#if !ZLOADER_APP_LAUNCH_TESTING
#import <UIKit/UIKit.h>
#endif

// The same runtime workspace interface is already used by zLoaderBackup.
@interface NSObject (ZLoaderNativeLaunch)
+ (id)defaultWorkspace;
- (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
                       usingConfiguration:(id)configuration
                        completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleIdentifier;
#if ZLOADER_APP_LAUNCH_TESTING
+ (id)sharedApplication;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^)(BOOL))completion;
#endif
@end

@implementation ZLoaderAppLauncher
+ (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
                        completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    [self openApplicationWithBundleIdentifier:bundleIdentifier registeredLaunchURL:nil completionHandler:completionHandler];
}

+ (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
                       registeredLaunchURL:(NSURL *)launchURL
                        completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"] invertedSet];
    if (bundleIdentifier.length == 0 || [bundleIdentifier rangeOfCharacterFromSet:invalid].location != NSNotFound) {
        completionHandler(NO, [NSError errorWithDomain:@"zLoader.AppLaunch" code:1 userInfo:@{
            NSLocalizedDescriptionKey: @"The installed app has an invalid bundle identifier."
        }]);
        return;
    }
    if (launchURL && (![launchURL.scheme.lowercaseString isEqualToString:[@"zloader-" stringByAppendingString:bundleIdentifier].lowercaseString]
                      || launchURL.host.length || launchURL.path.length || launchURL.query || launchURL.fragment)) {
        completionHandler(NO, [NSError errorWithDomain:@"zLoader.AppLaunch" code:1 userInfo:@{
            NSLocalizedDescriptionKey: @"The launch URL does not match the installed app."
        }]);
        return;
    }
    void (^finish)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        if (success || !launchURL) { completionHandler(success, error); return; }
        void (^openRegisteredURL)(void) = ^{
#if ZLOADER_APP_LAUNCH_TESTING
            id application = [NSClassFromString(@"ZLoaderTestApplication") sharedApplication];
#else
            UIApplication *application = UIApplication.sharedApplication;
#endif
            [application openURL:launchURL options:@{} completionHandler:^(BOOL opened) {
                completionHandler(opened, opened ? nil : error);
            }];
        };
        if (NSThread.isMainThread) { openRegisteredURL(); }
        else { dispatch_async(dispatch_get_main_queue(), openRegisteredURL); }
    };
#if ZLOADER_APP_LAUNCH_TESTING
    Class workspaceClass = NSClassFromString(@"ZLoaderTestApplicationWorkspace");
    Class configurationClass = NSClassFromString(@"ZLoaderTestOpenConfiguration");
#else
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    Class configurationClass = NSClassFromString(@"_LSOpenConfiguration");
#endif
    if (!workspaceClass || ![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        finish(NO, [NSError errorWithDomain:@"zLoader.AppLaunch" code:2 userInfo:@{
            NSLocalizedDescriptionKey: @"Direct app launch is unavailable on this system."
        }]);
        return;
    }
    id workspace = [workspaceClass defaultWorkspace];
    if (configurationClass && [workspace respondsToSelector:@selector(openApplicationWithBundleIdentifier:usingConfiguration:completionHandler:)]) {
        // Native launch delivers no deep link. On denial, only the exact
        // scheme installed by zLoader may be used; never a web URL or the
        // first arbitrary scheme declared by a third-party application.
        [workspace openApplicationWithBundleIdentifier:bundleIdentifier
                                   usingConfiguration:[[configurationClass alloc] init]
                                    completionHandler:finish];
    } else if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
        finish([workspace openApplicationWithBundleID:bundleIdentifier], nil);
    } else {
        finish(NO, [NSError errorWithDomain:@"zLoader.AppLaunch" code:2 userInfo:@{
            NSLocalizedDescriptionKey: @"Direct app launch is unavailable on this system."
        }]);
    }
}
@end
