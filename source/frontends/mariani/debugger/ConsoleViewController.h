//
//  ConsoleViewController.h
//  Mariani
//
//  Created by sh95014 on 5/31/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConsoleViewController : NSViewController

- (id)initWithTextView:(NSTextView *)textView;
- (void)themeDidChange;
- (void)update;

@end

NS_ASSUME_NONNULL_END
