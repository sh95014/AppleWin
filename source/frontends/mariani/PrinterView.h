//
//  PrinterView.h
//  Mariani
//
//  Created by sh95014 on 3/12/22.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrinterView : NSView

- (void)addString:(NSString *)string atPoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
