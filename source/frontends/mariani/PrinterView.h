//
//  PrinterView.h
//  Mariani
//
//  Created by sh95014 on 3/12/22.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class PrinterView;

@protocol PrinterViewDelegate

- (void)printerViewPageAdded:(PrinterView *)printerView;

@end

@interface PrinterView : NSView

- (void)addString:(NSString *)string atPoint:(CGPoint)point;
- (void)addPage;

- (void)showPage:(NSInteger)pageNumber;

@property (weak) IBOutlet id<PrinterViewDelegate> delegate;
@property (readonly) NSInteger pageCount;

@end

NS_ASSUME_NONNULL_END
