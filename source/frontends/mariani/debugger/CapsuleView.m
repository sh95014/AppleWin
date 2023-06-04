//
//  CapsuleView.m
//  Mariani
//
//  Created by sh95014 on 5/31/23.
//

#import "CapsuleView.h"

@interface CapsuleView () {
    NSMutableDictionary<NSAttributedStringKey,id> *_attributes;
    NSColor *_color;
    NSColor *_backgroundColor;
    NSArray<NSString *> *_titles;
    NSInteger _selectedIndex;
}
@end

@implementation CapsuleView

- (id)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect]) != nil) {
        [self configure];
    }
    return self;
}

- (void)awakeFromNib {
    [self configure];
}

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    self.layer.cornerRadius = frameRect.size.height / 2;
}

- (BOOL)wantsLayer {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    CGFloat totalTextWidth = 0;
    CGFloat height = 0;
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
    for (NSString *title in self.titles) {
        NSSize size = [title sizeWithAttributes:self.attributes];
        totalTextWidth += size.width;
        height = size.height;
        [widths addObject:@(size.width)];
    }
    
    const CGFloat totalWidth = self.bounds.size.width;
    const CGFloat titleY = floorf((self.bounds.size.height - height) / 2);
    const CGFloat margin = (totalWidth - totalTextWidth) / (self.titles.count + 1);
    const CGFloat halfMargin = margin / 2;
    CGFloat x = 0;
    for (NSInteger i = 0; i < self.titles.count; i++) {
        NSString *title = self.titles[i];
        const CGFloat titleWidth = widths[i].floatValue;
        const CGFloat titleX = floorf(x + margin);
        
        if (self.selectedIndex == i) {
            [self.color set];
            if (i == 0) {
                NSRectFill(CGRectMake(x, 0, floorf(margin + titleWidth + halfMargin), self.bounds.size.height));
            }
            else if (i == self.titles.count - 1) {
                NSRectFill(CGRectMake(floorf(x + halfMargin), 0, floorf(halfMargin + titleWidth + margin), self.bounds.size.height));
            }
            else {
                NSRectFill(CGRectMake(floorf(x + halfMargin), 0, floorf(halfMargin + titleWidth + halfMargin), self.bounds.size.height));
            }
            
            NSMutableDictionary<NSAttributedStringKey,id> *highlightedAttributes = [NSMutableDictionary dictionaryWithDictionary:self.attributes];
            [highlightedAttributes addEntriesFromDictionary:@{
                NSForegroundColorAttributeName : self.backgroundColor,
            }];
            [title drawAtPoint:CGPointMake(titleX, titleY) withAttributes:highlightedAttributes];
        }
        else {
            [title drawAtPoint:CGPointMake(titleX, titleY) withAttributes:self.attributes];
        }
        x += margin + titleWidth;
    }
}

- (void)setColor:(NSColor *)color {
    _color = color;
    self.layer.borderColor = color.CGColor;
    [self setNeedsDisplay:YES];
}

- (NSColor *)color {
    return _color;
}

- (void)setBackgroundColor:(NSColor *)backgroundColor {
    _backgroundColor = backgroundColor;
    self.layer.backgroundColor = backgroundColor.CGColor;
    [self setNeedsDisplay:YES];
}

- (NSColor *)backgroundColor {
    return _backgroundColor;
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attributes {
    _attributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
    [_attributes addEntriesFromDictionary:@{
        NSForegroundColorAttributeName : self.color,
    }];
    [self setNeedsDisplay:YES];
}

- (NSDictionary<NSAttributedStringKey,id> *)attributes {
    return _attributes;
}

- (void)setTitles:(NSArray<NSString *> *)titles {
    _titles = titles;
    [self setNeedsDisplay:YES];
}

- (NSArray<NSString *> *)titles {
    return _titles;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    _selectedIndex = selectedIndex;
    [self setNeedsDisplay:YES];
}

- (NSInteger)selectedIndex {
    return _selectedIndex;
}

#pragma mark - Internal

- (void)configure {
    self.color = [NSColor controlColor];
    self.backgroundColor = [NSColor controlBackgroundColor];
    
    self.layer.borderWidth = 1;
    self.layer.borderColor = self.color.CGColor;
    self.layer.cornerRadius = self.frame.size.height / 2;
}

@end
