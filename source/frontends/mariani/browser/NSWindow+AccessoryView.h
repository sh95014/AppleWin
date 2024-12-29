//
//  NSWindow+AccessoryView.h
//  Mariani
//
//  From http://fredandrandall.com/blog/2011/09/14/adding-a-button-or-view-to-the-nswindow-title-bar/
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSWindow (NSWindow_AccessoryView)
 
-(void)addViewToTitleBar:(NSView*)viewToAdd atXPosition:(CGFloat)x;
-(CGFloat)heightOfTitleBar;
 
@end

NS_ASSUME_NONNULL_END
