#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../App/Core/UI/ZLoaderAppLauncher.h"

static id workspace, testApplication;
static NSUInteger modernCalls, legacyCalls, payloadCalls, urlCalls;
static BOOL modernSucceeds, urlSucceeds;
static NSURL *receivedURL;
static id application(id object, SEL selector) { (void)object; (void)selector; return testApplication; }
static void openURL(id object, SEL selector, NSURL *url, NSDictionary *options, void (^completion)(BOOL)) {
    (void)object; (void)selector; (void)options; urlCalls++; receivedURL = url; completion(urlSucceeds);
}
static NSString *receivedBundle;
static id defaultWorkspace(id object, SEL selector) { (void)object; (void)selector; return workspace; }
static void setPayload(id object, SEL selector, id payload) { (void)object; (void)selector; (void)payload; payloadCalls++; }
static BOOL launchLegacy(id object, SEL selector, NSString *bundle) {
    (void)object; (void)selector;
    legacyCalls++; receivedBundle = bundle; return YES;
}
static void launchModern(id object, SEL selector, NSString *bundle, id configuration, void (^completion)(BOOL, NSError *)) {
    (void)object; (void)selector;
    modernCalls++; receivedBundle = bundle;
    NSCAssert(configuration != nil, @"Missing native configuration");
    completion(modernSucceeds, modernSucceeds ? nil : [NSError errorWithDomain:@"LSApplicationWorkspaceErrorDomain" code:115 userInfo:nil]);
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSString *mode = argc > 1 ? @(argv[1]) : @"unavailable";
        if (![mode isEqualToString:@"unavailable"]) {
            Class cls = objc_allocateClassPair(NSObject.class, "ZLoaderTestApplicationWorkspace", 0);
            class_addMethod(object_getClass(cls), @selector(defaultWorkspace), (IMP)defaultWorkspace, "@@:");
            class_addMethod(cls, NSSelectorFromString(@"openApplicationWithBundleID:"), (IMP)launchLegacy, "B@:@");
            if (![mode isEqualToString:@"legacy"]) {
                Class config = objc_allocateClassPair(NSObject.class, "ZLoaderTestOpenConfiguration", 0);
                class_addMethod(config, NSSelectorFromString(@"setFrontBoardOptions:"), (IMP)setPayload, "v@:@");
                objc_registerClassPair(config);
                class_addMethod(cls, NSSelectorFromString(@"openApplicationWithBundleIdentifier:usingConfiguration:completionHandler:"), (IMP)launchModern, "v@:@@@?");
            }
            objc_registerClassPair(cls); workspace = [[cls alloc] init];
        }
        Class app = objc_allocateClassPair(NSObject.class, "ZLoaderTestApplication", 0);
        class_addMethod(object_getClass(app), NSSelectorFromString(@"sharedApplication"), (IMP)application, "@@:");
        class_addMethod(app, NSSelectorFromString(@"openURL:options:completionHandler:"), (IMP)openURL, "v@:@@@?");
        objc_registerClassPair(app);
        testApplication = [[app alloc] init];
        BOOL fallback = [mode hasPrefix:@"fallback"];
        urlSucceeds = ![mode isEqualToString:@"fallback-failure"];
        modernSucceeds = [mode isEqualToString:@"modern-success"];
        BOOL invalid = [mode isEqualToString:@"invalid"];
        NSString *target = invalid ? @"https://example.invalid" : @"example.app.TESTTEAM";
        __block NSUInteger completions = 0;
        __block BOOL result = NO;
        NSURL *url = fallback ? [NSURL URLWithString:@"zloader-example.app.TESTTEAM://"] : nil;
        if ([mode isEqualToString:@"fallback-invalid"]) { url = [NSURL URLWithString:@"https://example.invalid"]; }
        [ZLoaderAppLauncher openApplicationWithBundleIdentifier:target registeredLaunchURL:url completionHandler:^(BOOL success, NSError *error) {
            completions++; result = success;
            if ([mode isEqualToString:@"fallback-failure"]) { NSCAssert(error.code == 115, @"Preserve the native error when fallback fails"); }
        }];
        NSCAssert(completions == 1 && payloadCalls == 0, @"Must complete once without a URL payload");
        if ([mode isEqualToString:@"fallback-invalid"]) {
            NSCAssert(!result && modernCalls == 0 && urlCalls == 0, @"Reject arbitrary/web launch URLs");
        } else if (fallback) {
            NSCAssert(result == urlSucceeds && modernCalls == 1 && urlCalls == 1 && legacyCalls == 0, @"Fallback must complete once after native denial");
            NSCAssert([receivedURL isEqual:url], @"Use only the exact registered launch scheme");
        } else if (invalid || [mode isEqualToString:@"unavailable"]) {
            NSCAssert(!result && modernCalls == 0 && legacyCalls == 0, @"Invalid/unavailable launch must not open anything");
        } else if ([mode isEqualToString:@"legacy"]) {
            NSCAssert(result && legacyCalls == 1 && modernCalls == 0, @"One legacy bundle launch only");
        } else {
            NSCAssert(result == modernSucceeds && modernCalls == 1 && legacyCalls == 0, @"Never retry after a modern launch result");
        }
        if (modernCalls + legacyCalls) { NSCAssert([receivedBundle isEqualToString:target], @"Must use the actual resigned bundle identifier"); }
        printf("PASS native app launcher: %s\n", mode.UTF8String);
    }
    return 0;
}
