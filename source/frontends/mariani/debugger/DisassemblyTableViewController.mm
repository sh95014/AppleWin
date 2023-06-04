//
//  DisassemblyTableViewController.mm
//  Mariani
//
//  Created by sh95014 on 5/29/23.
//

#import "DisassemblyTableViewController.h"
#import "NSColor+AppleWin.h"
#import "Carbon/Carbon.h"
#import "SymbolTable.h"

#import "StdAfx.h"
#import "CPU.h"
#import "Debug.h"

#define VERTICAL_MARGIN             2

#define DISASM_LINES                1000
#define DISASM_FONT                 [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular]
#define FG_DISASM_DEFAULT           FG_DISASM_OPCODE

// Order needs to match Debugger.xib
enum DisassemblyTableColumns {
    DisassemblyBreakpointColumn,
    DisassemblyAddressColumn,
    DisassemblyBookmarkColumn,
    DisassemblySymbolColumn,
    DisassemblyOpcodeColumn,
    DisassemblyDisassemblyColumn,
    DisassemblyTargetColumn,
    DisassemblyBranchColumn,
    DisassemblyImmediateCharColumn,
};

@interface DisassemblyLine : NSObject {
@public
    DisasmLine_t line;
}

@property (assign) WORD address;
@property (strong) NSString *symbol;
@property (assign) int bDisasmFormatFlags;

@end

@implementation DisassemblyLine

@end

@implementation NSTableView (Centering)

- (void)scrollRowToCenter:(NSInteger)row {
    CGRect rowFrame = [self frameOfCellAtColumn:DisassemblyBreakpointColumn row:row];
    NSScrollView *scrollView = self.enclosingScrollView;
    NSPoint top = NSMakePoint(0, CGRectGetMidY(rowFrame) - scrollView.frame.size.height / 2);
    [self scrollPoint:top];
}

@end

@interface DisassemblyTableViewController ()

@property (weak) NSTableView *tableView;
@property (strong) NSMutableArray<DisassemblyLine *> *disasmLines;
@property (assign) NSInteger rowHeight;
@property (assign) NSInteger pcRow;

@end

@implementation DisassemblyTableViewController

- (id)initWithTableView:(NSTableView *)tableView {
    if ((self = [super init]) != nil) {
        self.view = self.tableView = tableView;
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.action = @selector(tableClicked:);
        
        NSMenu *menu = [[NSMenu alloc] init];
        [menu addItemWithTitle:NSLocalizedString(@"Toggle Breakpoint", @"") action:@selector(toggleBreakpointAction:) keyEquivalent:@""];
        [menu addItemWithTitle:NSLocalizedString(@"Clear Breakpoint", @"") action:@selector(clearBreakpointAction:) keyEquivalent:@""];
        [menu addItemWithTitle:NSLocalizedString(@"Toggle Bookmark", @"") action:@selector(toggleBookmarkAction:) keyEquivalent:@""];
        self.tableView.menu = menu;
        
        [self disassembleFromTopAddress];
    }
    return self;
}

- (void)tableClicked:(id)sender {
    NSAssert(self.tableView.allowsColumnReordering == NO, @"method assumes column numbers");
    switch (self.tableView.clickedColumn) {
        case DisassemblyBreakpointColumn:
        case DisassemblyAddressColumn:
            [self toggleBreakpointAction:sender];
            break;
        case DisassemblyBookmarkColumn:
            [self toggleBookmarkAction:sender];
            break;
    }
}

- (void)toggleBreakpointAction:(id)sender {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0 && row < self.disasmLines.count) {
        DisassemblyLine *disasmLine = self.disasmLines[row];
        bool breakpointActive, breakpointEnabled;
        GetBreakpointInfo(disasmLine.address, breakpointActive, breakpointEnabled);
        if (!breakpointActive) {
            if ([self.delegate respondsToSelector:@selector(sendDebuggerCommand:refresh:)]) {
                NSString *cmd = [NSString stringWithFormat:@"bpx %x", disasmLine.address];
                [self.delegate sendDebuggerCommand:cmd refresh:NO];
            }
        }
        else {
            [self toggleBreakpointAtAddress:disasmLine.address];
        }
        [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:DisassemblyBreakpointColumn]];
    }
}

- (void)clearBreakpointAction:(id)sender {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0 && row < self.disasmLines.count) {
        DisassemblyLine *disasmLine = self.disasmLines[row];
        NSInteger index;
        if ([self breakpointAtAddress:disasmLine.address index:&index] != NULL &&
            [self.delegate respondsToSelector:@selector(sendDebuggerCommand:refresh:)]) {
            NSString *cmd = [NSString stringWithFormat:@"bpc %ld", index];
            [self.delegate sendDebuggerCommand:cmd refresh:YES];
        }
    }
}

- (void)toggleBookmarkAction:(id)sender {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0 && row < self.disasmLines.count) {
        DisassemblyLine *disasmLine = self.disasmLines[row];
        [self toggleBookmarkAtAddress:disasmLine.address];
        [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:DisassemblyBookmarkColumn]];
        if ([self.delegate respondsToSelector:@selector(refreshBookmarks)]) {
            [self.delegate refreshBookmarks];
        }
    }
}

- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case kVK_RightArrow:
        case kVK_Tab:
            if (self.pcRow == NSNotFound) {
                [self reloadData:YES];
            }
            else {
                [self.tableView scrollRowToVisible:self.pcRow];
            }
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.pcRow] byExtendingSelection:NO];
            break;
        default:
            break;
    }
}

- (void)reloadData:(BOOL)syncPC {
    NSUInteger pc = regs.pc;
    g_nDisasmTopAddress = (WORD)((pc - DISASM_LINES / 2) & 0xFFFF);
    
    [self disassembleFromTopAddress];
    [self.tableView reloadData];
    if (syncPC) {
        [self.tableView scrollRowToCenter:self.pcRow];
    }
}

- (void)recenterAtAddress:(NSUInteger)address {
    g_nDisasmTopAddress = (WORD)((address - DISASM_LINES / 2) & 0xFFFF);
    
    [self disassembleFromTopAddress];
    [self.tableView reloadData];
    NSInteger row = [self rowWithAddress:address];
    if (row != NSNotFound) {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:row];
        [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
        [self.tableView scrollRowToCenter:row];
    }
}

- (void)selectBookmark:(NSInteger)index {
    NSInteger address = [self addressOfBookmark:index];
    [self recenterAtAddress:address];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if ([obj.object isKindOfClass:[NSTextField class]]) {
        NSTextField *textField = (NSTextField *)obj.object;
        NSString *symbol = textField.stringValue;
        NSMutableCharacterSet *legalCharacters = [NSMutableCharacterSet characterSetWithCharactersInString:
            @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz."];
        if ([symbol rangeOfCharacterFromSet:legalCharacters.invertedSet].location == NSNotFound &&
            [self.delegate respondsToSelector:@selector(sendDebuggerCommand:refresh:)]) {
            NSString *cmd = [NSString stringWithFormat:@"sym %@ = %lx", textField.stringValue, textField.tag];
            [self.delegate sendDebuggerCommand:cmd refresh:NO];
            
            textField.attributedStringValue = [self attributedString:symbol ofType:NSColorTypeDisassemblerSymbol];
            [[NSNotificationCenter defaultCenter] postNotificationName:SymbolTableDidChangeNotification object:self];
        }
        else {
            [self.tableView reloadData];
        }
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.disasmLines.count;
}

#pragma mark - NSTableViewDelegate

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (self.rowHeight == 0) {
        self.rowHeight = DISASM_FONT.boundingRectForFont.size.height + VERTICAL_MARGIN * 2;
    }
    return self.rowHeight;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    DisassemblyLine *disasmLine = self.disasmLines[row];
    
    NSImageView *imageView = nil;
    NSTextField *textField = nil;
    NSLayoutAttribute alignment = NSLayoutAttributeLeft;
    if ([tableColumn.identifier isEqualToString:@"breakpoint"]) {
        NSInteger index;
        Breakpoint_t *bp = [self breakpointAtAddress:disasmLine.address index:&index];
        
        if (bp != NULL) {
            if (bp->bSet) {
                if (bp->bEnabled) {
                    NSString *symbol = [NSString stringWithFormat:@"%lx.square.fill", index];
                    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@""];
                    if (@available(macOS 12.0, *)) {
                        NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPaletteColors:@[
                            [NSColor colorForType:NSColorTypeBreakpoint], [NSColor colorForType:NSColorTypeBreakpointBackground]
                        ]];
                        imageView = [NSImageView imageViewWithImage:[image imageWithSymbolConfiguration:config]];
                    } else {
                        imageView = [NSImageView imageViewWithImage:image];
                        imageView.contentTintColor = [NSColor colorForType:NSColorTypeBreakpointBackground];
                    }
                }
                else {
                    NSString *symbol = [NSString stringWithFormat:@"%lx.square", index];
                    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@""];
                    imageView = [NSImageView imageViewWithImage:image];
                    imageView.contentTintColor = [NSColor colorForType:NSColorTypeBreakpointBackground];
                }
            }
        }
        alignment = NSLayoutAttributeCenterX;
    }
    else if ([tableColumn.identifier isEqualToString:@"address"]) {
        textField = [self textFieldWithString:[NSString stringWithUTF8String:disasmLine->line.sAddress] ofType:NSColorTypeDisassemblerAddress];
        alignment = NSLayoutAttributeCenterX;
    }
    else if ([tableColumn.identifier isEqualToString:@"bookmark"]) {
        NSInteger index;
        Bookmark_t *bm = [self bookmarkAtAddress:disasmLine.address index:&index];
        
        if (bm != NULL) {
            if (bm->bSet) {
                NSString *symbol = [NSString stringWithFormat:@"%lx.circle.fill", index];
                NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@""];
                if (@available(macOS 12.0, *)) {
                    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPaletteColors:@[
                        [NSColor colorForType:NSColorTypeBookmark], [NSColor colorForType:NSColorTypeBookmarkBackground]
                    ]];
                    imageView = [NSImageView imageViewWithImage:[image imageWithSymbolConfiguration:config]];
                } else {
                    imageView = [NSImageView imageViewWithImage:image];
                    imageView.contentTintColor = [NSColor colorForType:NSColorTypeBookmarkBackground];
                }
            }
        }
        alignment = NSLayoutAttributeCenterX;
    }
    else if ([tableColumn.identifier isEqualToString:@"opcode"]) {
        textField = [self textFieldWithString:[NSString stringWithUTF8String:disasmLine->line.sOpCodes] ofType:NSColorTypeDisassemblerOpcode];
    }
    else if ([tableColumn.identifier isEqualToString:@"symbol"]) {
        if (disasmLine.symbol != nil) {
            textField = [self textFieldWithString:disasmLine.symbol ofType:NSColorTypeDisassemblerSymbol];
        }
        else {
            textField = [self textFieldWithString:@"" ofType:NSColorTypeDisassemblerSymbol];
        }
        textField.delegate = self;
        textField.tag = disasmLine.address;
        textField.editable = YES;
    }
    else if ([tableColumn.identifier isEqualToString:@"disassembly"]) {
        // instruction/mnemonic, target
        NSMutableAttributedString *disassembly = [[NSMutableAttributedString alloc] init];
        
        NSString *opcode = [NSString stringWithFormat:@"%s ", g_aOpcodes[disasmLine->line.iOpcode].sMnemonic];
        [disassembly appendAttributedString:[self attributedString:opcode ofType:NSColorTypeDisassemblerMnemonic]];
        
        if (disasmLine->line.bTargetImmediate) {
            [disassembly appendAttributedString:[self attributedString:@"#$" ofType:NSColorTypeDisassemblerImmediatePrefix]];
        }
        if (disasmLine->line.bTargetIndexed || disasmLine->line.bTargetIndirect) {
            [disassembly appendAttributedString:[self attributedString:@"(" ofType:NSColorTypeDisassemblerParenthesis]];
        }
        
        NSColorTypeMariani targetType;
        if (disasmLine.bDisasmFormatFlags & DISASM_FORMAT_SYMBOL) {
            targetType = NSColorTypeDisassemblerSymbol;
        }
        else if (disasmLine->line.iOpmode == AM_M) {
            targetType = NSColorTypeDisassemblerImmediateValue;
        }
        else {
            targetType = NSColorTypeDisassemblerOperand;
        }
        NSString *target = [NSString stringWithUTF8String:disasmLine->line.sTarget];
        if ([target hasPrefix:@"$"]) {
            [disassembly appendAttributedString:[self attributedString:@"$" ofType:NSColorTypeDisassemblerHexPrefix]];
            [disassembly appendAttributedString:[self attributedString:[target substringFromIndex:1] ofType:targetType]];
        }
        else {
            [disassembly appendAttributedString:[self attributedString:target ofType:targetType]];
        }
        if (disasmLine.bDisasmFormatFlags & DISASM_FORMAT_OFFSET) {
            if (disasmLine->line.nTargetOffset > 0) {
                [disassembly appendAttributedString:[self attributedString:@"+" ofType:NSColorTypeDisassemblerOperator]];
            }
            else if (disasmLine->line.nTargetOffset < 0) {
                [disassembly appendAttributedString:[self attributedString:@"-" ofType:NSColorTypeDisassemblerOperator]];
            }
            [disassembly appendAttributedString:[self attributedString:[NSString stringWithUTF8String:disasmLine->line.sTargetOffset] ofType:NSColorTypeDisassemblerTargetOffset]];
        }
        if (disasmLine->line.bTargetX) {
            [disassembly appendAttributedString:[self attributedString:@"," ofType:NSColorTypeDisassemblerSeparator]];
            [disassembly appendAttributedString:[self attributedString:@"X" ofType:NSColorTypeDisassemblerRegisterOperand]];
        }
        else if ((disasmLine->line.bTargetY) && (!disasmLine->line.bTargetIndirect)) {
            [disassembly appendAttributedString:[self attributedString:@"," ofType:NSColorTypeDisassemblerSeparator]];
            [disassembly appendAttributedString:[self attributedString:@"Y" ofType:NSColorTypeDisassemblerRegisterOperand]];
        }
        if (disasmLine->line.bTargetIndexed || disasmLine->line.bTargetIndirect) {
            [disassembly appendAttributedString:[self attributedString:@")" ofType:NSColorTypeDisassemblerParenthesis]];
        }
        if (disasmLine->line.bTargetIndexed && disasmLine->line.bTargetY) {
            [disassembly appendAttributedString:[self attributedString:@"," ofType:NSColorTypeDisassemblerSeparator]];
            [disassembly appendAttributedString:[self attributedString:@"Y" ofType:NSColorTypeDisassemblerRegisterOperand]];
        }
        
        textField = [NSTextField labelWithAttributedString:disassembly];
    }
    else if ([tableColumn.identifier isEqualToString:@"target_value_immediate"]) {
        // memory pointer and value; decimal for immediate values
        if (disasmLine.bDisasmFormatFlags & DISASM_FORMAT_TARGET_POINTER) {
            NSMutableAttributedString *targetValue = [[NSMutableAttributedString alloc] init];
            [targetValue appendAttributedString:[self attributedString:@(disasmLine->line.sTargetPointer) ofType:NSColorTypeDisassemblerAddress]];
            if (disasmLine.bDisasmFormatFlags & DISASM_FORMAT_TARGET_VALUE) {
                [targetValue appendAttributedString:[self attributedString:@":" ofType:NSColorTypeDisassemblerSeparator]];
                [targetValue appendAttributedString:[self attributedString:@(disasmLine->line.sTargetValue) ofType:NSColorTypeDisassemblerImmediateValue]];
            }
            textField = [NSTextField labelWithAttributedString:targetValue];
        }
        else if (disasmLine->line.bTargetImmediate && disasmLine->line.nImmediate) {
            NSMutableAttributedString *immediate = [[NSMutableAttributedString alloc] init];
            [immediate appendAttributedString:[self attributedString:@"#" ofType:NSColorTypeDisassemblerImmediatePrefix]];
            [immediate appendAttributedString:[self attributedString:@(disasmLine->line.sImmediateSignedDec) ofType:NSColorTypeDisassemblerImmediateDecimal]];
            textField = [NSTextField labelWithAttributedString:immediate];
        }
        alignment = NSLayoutAttributeCenterX;
    }
    else if ([tableColumn.identifier isEqualToString:@"branch"]) {
        // branch indicator
        if (disasmLine.bDisasmFormatFlags & DISASM_FORMAT_BRANCH) {
            NSImage *image;
            if ((unsigned char)*disasmLine->line.sBranch == 0x8A) {
                image = [NSImage imageWithSystemSymbolName:@"arrow.uturn.down" accessibilityDescription:@""];
            }
            else if ((unsigned char)*disasmLine->line.sBranch == 0x8B) {
                image = [NSImage imageWithSystemSymbolName:@"arrow.uturn.up" accessibilityDescription:@""];
            }
            if (image != nil) {
                imageView = [NSImageView imageViewWithImage:image];
                imageView.contentTintColor = [NSColor colorForType:NSColorTypeDisassemblerBranchDirection];
            }
        }
        alignment = NSLayoutAttributeCenterX;
    }
    else if ([tableColumn.identifier isEqualToString:@"char"]) {
        // immediate char
        if (disasmLine.bDisasmFormatFlags & DISASM_FORMAT_CHAR) {
            // See ColorizeSpecialChar( line.nImmediate, MEM_VIEW_ASCII, iBackground );
            NSColorTypeMariani type;
            NSInteger c = (unsigned char)disasmLine->line.nImmediate;
            if ((c & 0x7F) < 0x20) {
                // "bCtrlBit"
                type = NSColorTypeDisassemblerImmediateCharControl;
            }
            else if (c > 0x7F) {
                // "bHighBit"
                type = NSColorTypeDisassemblerImmediateCharHigh;
            }
            else {
                type = NSColorTypeDisassemblerImmediateChar;
            }
            NSString *s = (c != 0xFF) ? @(disasmLine->line.sImmediate) : @"\u2591"; // "light shade"
            textField = [self textFieldWithString:s ofType:type];
        }
        alignment = NSLayoutAttributeCenterX;
    }
    
    NSView *enclosingView = [[NSView alloc] initWithFrame:CGRectMake(0, 0, tableColumn.width, self.rowHeight)];
    
    // make sure that the current line remains legible because it's highlighted
    if (textField != nil) {
        textField.font = DISASM_FONT;
        if (disasmLine.address == regs.pc) {
            textField.stringValue = textField.attributedStringValue.string;
            textField.textColor = [NSColor colorForType:NSColorTypeDisassemblerHighlighted];
        }
        if (textField.editable) {
            // give it the whole width of the column
            CGRect frame = textField.frame;
            frame.size.width = tableColumn.width;
            textField.frame = frame;
        }
        [enclosingView addSubview:textField];
    }
    else if (imageView != nil) {
        if (disasmLine.address == regs.pc) {
            imageView.contentTintColor = [NSColor colorForType:NSColorTypeDisassemblerHighlighted];
        }
        [enclosingView addSubview:imageView];
    }
    
    for (NSView *view in enclosingView.subviews) {
        // vertically center all subviews within enclosingView
        CGRect frame = view.frame;
        frame.origin.y = VERTICAL_MARGIN;
        
        // apply horizontal alignment
        switch (alignment) {
            case NSLayoutAttributeCenterX:
                frame.origin.x = floorf((enclosingView.bounds.size.width - frame.size.width) / 2);
                break;
            case NSLayoutAttributeRight:
                frame.origin.x = floorf(enclosingView.bounds.size.width - frame.size.width);
                break;
            default:
                break;
        }
        
        view.frame = frame;
    }
    
    return enclosingView;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    DisassemblyLine *disasmLine = self.disasmLines[row];
    if (disasmLine.address == regs.pc) {
        // FIXME: ConfigColorsReset() seems to set FG_DISASM_PC_X and BG_DISASM_PC_X both to white
        //        in Black & White mode, so we substitute our own highlight color instead.
        // rowView.backgroundColor = [NSColor colorForType:BG_DISASM_PC_X];
        rowView.backgroundColor = [NSColor colorNamed:@"ASMCurrentLineBackgroundColor"];
    }
    else {
        rowView.backgroundColor = [NSColor colorForType:(row % 2) ? NSColorTypeDisassemblerBackground1 : NSColorTypeDisassemblerBackground2];
    }
}

#pragma mark - Internal

- (void)disassembleFromTopAddress {
    self.pcRow = NSNotFound;
    self.disasmLines = [NSMutableArray arrayWithCapacity:DISASM_LINES];
    
    WORD nAddress = g_nDisasmTopAddress;
    for (NSInteger i = 0; i < DISASM_LINES; i++) {
        DisassemblyLine *disasmLine = [[DisassemblyLine alloc] init];
        
        disasmLine.address = nAddress;
        if (nAddress == regs.pc) {
            self.pcRow = i;
        }
        
        std::string const * pSymbol = FindSymbolFromAddress(nAddress);
        if (pSymbol != NULL) {
            disasmLine.symbol = [NSString stringWithUTF8String:pSymbol->c_str()];
        }
        
        disasmLine.bDisasmFormatFlags = GetDisassemblyLine(nAddress, disasmLine->line);
        
        [self.disasmLines addObject:disasmLine];
        nAddress += disasmLine->line.nOpbyte;
    }
    [self.tableView reloadData];
}

- (NSTextField *)textFieldWithString:(NSString *)string ofType:(NSColorTypeMariani)type {
    if (string == nil) {
        return nil;
    }
    return [NSTextField labelWithAttributedString:[self attributedString:string ofType:type]];
}

- (NSAttributedString *)attributedString:(NSString *)string ofType:(NSColorTypeMariani)type {
    NSDictionary *attributes = @{
        NSFontAttributeName : DISASM_FONT,
        NSForegroundColorAttributeName : [NSColor colorForType:type],
    };
    return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

- (void)toggleBreakpointAtAddress:(WORD)address {
    for (Breakpoint_t & bp : g_aBreakpoints) {
        if (bp.bSet && bp.nLength && (address >= bp.nAddress) && (address < bp.nAddress + bp.nLength)) {
            bp.bEnabled = !bp.bEnabled;
            return;
        }
    }
}

- (Breakpoint_t *)breakpointAtAddress:(WORD)address index:(NSInteger *)indexPointer {
    for (NSInteger i = 0; i < MAX_BREAKPOINTS; i++) {
        Breakpoint_t *bp = g_aBreakpoints + i;
        if (bp->bSet && bp->nLength && (address >= bp->nAddress) && (address < bp->nAddress + bp->nLength)) {
            if (indexPointer != nil) {
                *indexPointer = i;
            }
            return bp;
        }
    }
    if (indexPointer != nil) {
        *indexPointer = NSNotFound;
    }
    return NULL;
}

- (void)toggleBookmarkAtAddress:(WORD)address {
    for (Bookmark_t & bm : g_aBookmarks) {
        if (bm.bSet && address == bm.nAddress) {
            bm.bSet = !bm.bSet;
            return;
        }
    }
    
    // none found, create a bookmark here
    if ([self.delegate respondsToSelector:@selector(sendDebuggerCommand:refresh:)]) {
        NSString *cmd = [NSString stringWithFormat:@"bma %x", address];
        [self.delegate sendDebuggerCommand:cmd refresh:NO];
    }
}

- (Bookmark_t *)bookmarkAtAddress:(WORD)address index:(NSInteger *)indexPointer {
    for (NSInteger i = 0; i < MAX_BOOKMARKS; i++) {
        Bookmark_t *bm = g_aBookmarks + i;
        if (bm->bSet && address == bm->nAddress) {
            if (indexPointer != nil) {
                *indexPointer = i;
            }
            return bm;
        }
    }
    if (indexPointer != nil) {
        *indexPointer = NSNotFound;
    }
    return NULL;
}

- (NSInteger)addressOfBookmark:(NSInteger)index {
    return g_aBookmarks[index].bSet ? g_aBookmarks[index].nAddress : NSNotFound;
}

- (NSInteger)rowWithAddress:(WORD)address {
    return [self.disasmLines indexOfObjectPassingTest:^BOOL(DisassemblyLine * _Nonnull disasmLine, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL found = (disasmLine.address == address);
        *stop = found;
        return found;
    }];
}

@end
