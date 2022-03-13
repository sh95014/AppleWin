//
//  PrinterView.m
//  Mariani
//
//  Created by sh95014 on 3/12/22.
//

#import "PrinterView.h"

@interface PrinterString : NSObject
@property (strong) NSString *string;
@property (assign) CGPoint location;
@end

@implementation PrinterString
#ifdef DEBUG
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%.1f, %.1f) \"%@\"", [super description], self.location.x, self.location.y, self.string];
}
#endif // DEBUG
@end

@interface PrinterView ()

@property (strong) NSMutableArray<PrinterString *> *strings;
@property (strong) NSFont *font;
@property (strong) NSDictionary *fontAttributes;

@end

@implementation PrinterView

- (void)awakeFromNib {
    self.strings = [NSMutableArray array];
    self.font = [NSFont fontWithName:@"FXMatrix105MonoEliteRegular" size:9];
    
    // To match the resolution of AppleWriterPrinter, we assume 72 dpi and
    // the default Elite font is 12 cpi, so we want our character spacing to
    // fit 12 characters per "inch" on the screen.
    const CGFloat fontWidth = self.font.maximumAdvancement.width;
    const CGFloat characterWidth = (self.bounds.size.width / 8.5) / 12.0;
    
    // But unfortunately, that math seems to be slightly off, possibly because
    // maximumAdvancement is lying, so let's fudge  it based on real
    // measurements:
    const CGFloat kerning = (characterWidth - fontWidth) * 0.925;
    
    self.fontAttributes = @{
        NSFontAttributeName: self.font,
        NSKernAttributeName: @(kerning),
    };
}

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[NSColor whiteColor] setFill];
    NSRectFill(dirtyRect);
    
    [[NSColor blackColor] setStroke];
    for (PrinterString *ps in self.strings) {
        [ps.string drawAtPoint:ps.location withAttributes:self.fontAttributes];
    }
}

- (void)addString:(NSString *)string atPoint:(CGPoint)location {
    PrinterString *printerString = [[PrinterString alloc] init];
    printerString.string = string;
    printerString.location = location;
    [self.strings addObject:printerString];
    
    [self setNeedsDisplay:YES];
}

@end
