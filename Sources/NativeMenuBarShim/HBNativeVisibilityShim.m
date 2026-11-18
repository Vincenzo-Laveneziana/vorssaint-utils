// SPDX-License-Identifier: GPL-3.0-or-later
// Native visibility bridge for macOS 27, adapted from Hidden Bar (MIT).
#import "HBNativeVisibilityShim.h"
#import <dlfcn.h>
#import <objc/message.h>

static NSString *const HBErrorDomain = @"VorssaintNativeVisibility";
static NSString *const HBFrameworkPath = @"/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore";
static NSString *const HBConfigurationClassName = @"MBAssessmentModeConfiguration";
static NSString *const HBAssertionClassName = @"MBAssessmentModeAssertion";
static SEL HBConfigurationInit(void) { return @selector(initWithAllowedSystemItems:allowedBundleIdentifiers:); }
static SEL HBActivate(void) { return @selector(activateWithConfiguration:completionHandler:); }
static SEL HBInvalidate(void) { return @selector(invalidate); }
static NSError *HBError(NSString *message) {
    return [NSError errorWithDomain:HBErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

BOOL HBNativeVisibilityIsAvailable(void) {
    if (!dlopen(HBFrameworkPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL)) return NO;
    Class configuration = NSClassFromString(HBConfigurationClassName);
    Class assertion = NSClassFromString(HBAssertionClassName);
    return configuration && assertion
        && [configuration instancesRespondToSelector:HBConfigurationInit()]
        && [assertion instancesRespondToSelector:HBActivate()]
        && [assertion instancesRespondToSelector:HBInvalidate()];
}

void HBNativeVisibilityActivate(NSArray<NSNumber *> *systemItems,
                                NSArray<NSString *> *bundleIdentifiers,
                                void (^completion)(id, NSError *)) {
    void (^finish)(id, NSError *) = ^(id assertion, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(assertion, error); });
    };
    if (!HBNativeVisibilityIsAvailable()) {
        finish(nil, HBError(@"The macOS native menu bar visibility API is unavailable."));
        return;
    }
    @try {
        id configuration = ((id (*)(id, SEL, NSArray *, NSArray *))objc_msgSend)(
            [NSClassFromString(HBConfigurationClassName) alloc], HBConfigurationInit(),
            [systemItems copy], [bundleIdentifiers copy]);
        id assertion = [[NSClassFromString(HBAssertionClassName) alloc] init];
        if (!configuration || !assertion) {
            finish(nil, HBError(@"Could not create the menu bar visibility configuration."));
            return;
        }
        ((void (*)(id, SEL, id, void (^)(NSError *)))objc_msgSend)(
            assertion, HBActivate(), configuration, ^(NSError *error) {
                finish(error ? nil : assertion, error);
            });
    } @catch (NSException *exception) {
        finish(nil, HBError([NSString stringWithFormat:@"%@ %@", exception.name, exception.reason ?: @""]));
    }
}

void HBNativeVisibilityInvalidate(id assertion) {
    @try {
        if ([assertion respondsToSelector:HBInvalidate()])
            ((void (*)(id, SEL))objc_msgSend)(assertion, HBInvalidate());
    } @catch (NSException *exception) {
        NSLog(@"Vorssaint: native menu bar visibility reset failed: %@", exception);
    }
}
