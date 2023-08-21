//
//  ConsoleViewController.mm
//  Mariani
//
//  Created by sh95014 on 5/31/23.
//

#import "ConsoleViewController.h"
#import "StdAfx.h"
#import "Debugger_Types.h"
#import "Debugger_Console.h"
#import "NSColor+AppleWin.h"
#import "NSFont+Mariani.h"

@interface ConsoleViewController ()

@property (weak) NSTextView *textView;
@property (assign) int totalAppended;

@end

@implementation ConsoleViewController

static NSString *mouseTextMapping = @"⬉⌛︎✓☑︎↵�←…↓↑‾↵█⇤⇥⤓⤒―⌞→▦▩⟦⟧⎥♦︎�✛⊡⎢";

- (id)initWithTextView:(NSTextView *)textView {
    NSAssert((int)NSColorModeAppleWinColor == (int)SCHEME_COLOR, @"");
    NSAssert((int)NSColorModeAppleWinMonochrome == (int)SCHEME_MONO, @"");
    NSAssert((int)NSColorModeAppleWinBlackAndWhite == (int)SCHEME_BW, @"");
    
    if ((self = [super init]) != nil) {
        self.view = self.textView = textView;
        
        self.textView.editable = NO;
        self.textView.backgroundColor = [NSColor colorForType:NSColorTypeConsoleOutputDefaultBackground];
        
        [self reload];
    }
    return self;
}

- (void)viewDidAppear {
    [self.textView scrollToEndOfDocument:self];
}

- (void)themeDidChange {
    [self reload];
}

#pragma mark - Internal

- (void)reload {
    NSAttributedString *emptyAttrString = [[NSAttributedString alloc] initWithString:@""];
    [self.textView.textStorage setAttributedString:emptyAttrString];
    
    self.totalAppended = 0;
    [self update];
}

- (void)update {
    for (int i = g_nConsoleDisplayTotal - self.totalAppended; i >= CONSOLE_FIRST_LINE; --i) {
        [self appendConsoleLine:g_aConsoleDisplay[i]];
    }
    self.totalAppended = g_nConsoleDisplayTotal;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView scrollToEndOfDocument:self];
    });
}

- (void)appendConsoleLine:(conchar_t *)line {
    char charBuffer[CONSOLE_WIDTH + 2]; // +1 for LF, +1 for NUL
    __block size_t charIndex = 0;
    __block NSColor *color = [NSColor colorForType:NSColorTypeConsoleOutputDefault];
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary: @{
        NSFontAttributeName : [NSFont myMonospacedSystemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightRegular],
    }];

    void (^emit)(char *) = ^(char *charBuffer) {
        if (charIndex > 0) {
            // output accumulated buffer
            charBuffer[charIndex] = 0;
            
            [attributes setValue:color forKey:NSForegroundColorAttributeName];
            
            NSString *string = [NSString stringWithUTF8String:charBuffer];
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:string attributes:attributes];
            [self.textView.textStorage appendAttributedString:attrString];
            
            charIndex = 0;
        }
    };

    for (const conchar_t *c = line; *c; c++) {
        if (ConsoleColor_IsColor(*c)) {
            emit(charBuffer);
            color = [NSColor colorFromCOLORREF:ConsoleColor_GetColor(*c) mode:(NSColorModeAppleWin)g_iColorScheme];
        }
        if (*c & 0x80) {
            // mouse text
            emit(charBuffer);
            
            NSString *mouseChar = [mouseTextMapping substringWithRange:NSMakeRange(*c & 0x1F, 1)];
            [attributes setValue:color forKey:NSForegroundColorAttributeName];
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:mouseChar attributes:attributes];
            [self.textView.textStorage appendAttributedString:attrString];
        }
        else {
            charBuffer[charIndex++] = ConsoleChar_GetChar(*c);
        }
    }
    charBuffer[charIndex++] = '\n';
    emit(charBuffer);
}

@end
