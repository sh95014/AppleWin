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

- (void)printerView:(PrinterView *)printerView printedToPage:(NSInteger)pageNumber;
- (void)printerViewPageAdded:(PrinterView *)printerView;

@end

@interface PrinterView : NSView

- (void)addString:(NSString *)string atPoint:(CGPoint)point;
- (void)plotAtPoint:(CGPoint)location;
- (void)addPage;
- (void)setFontSize:(CGSize)size;

- (void)showPage:(NSInteger)pageNumber;

- (NSImage *)imageThumbnailOfPage:(NSInteger)pageNumber withDPI:(NSInteger)dpi;

@property (weak) IBOutlet id<PrinterViewDelegate> delegate;
@property (readonly) NSInteger pageCount;

@end

NS_ASSUME_NONNULL_END
