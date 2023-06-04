//
//  CapsuleView.h
//  Mariani
//
//  Created by sh95014 on 5/31/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CapsuleView : NSView

@property (strong) NSColor *color;
@property (strong) NSColor *backgroundColor;
@property (strong) NSArray<NSString *> *titles;
@property (assign) NSInteger selectedIndex;
@property (strong) NSDictionary<NSAttributedStringKey, id> *attributes;

@end

NS_ASSUME_NONNULL_END
