//
//  PreferencesViewController.h
//  Mariani
//
//  Created by sh95014 on 12/30/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreferencesViewController : NSViewController

// cardType is actually SS_CARDTYPE, but avoiding C++ header inclusion
// here for simplicity.
+ (NSString *)cardNameForType:(unsigned)cardType;

@end

NS_ASSUME_NONNULL_END
