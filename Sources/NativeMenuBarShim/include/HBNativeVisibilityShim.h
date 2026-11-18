// SPDX-License-Identifier: GPL-3.0-or-later
// Native visibility bridge for macOS 27, adapted from Hidden Bar (MIT).
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
BOOL HBNativeVisibilityIsAvailable(void);
void HBNativeVisibilityActivate(NSArray<NSNumber *> *allowedSystemItems,
                                NSArray<NSString *> *allowedBundleIdentifiers,
                                void (^completion)(id _Nullable assertion, NSError * _Nullable error));
void HBNativeVisibilityInvalidate(id assertion);
NS_ASSUME_NONNULL_END
