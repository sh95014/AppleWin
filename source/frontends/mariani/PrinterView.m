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
@end

@interface PrinterView ()

@property (strong) NSMutableArray<PrinterString *> *strings;
@property (strong) NSFont *font;

@end

@implementation PrinterView

- (void)awakeFromNib {
    self.strings = [NSMutableArray array];
    self.font = [NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightRegular];
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
        [ps.string drawAtPoint:ps.location withAttributes:@{ NSFontAttributeName:self.font }];
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
