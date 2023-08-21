//
//  DebuggerWindowController.mm
//  Mariani
//
//  Created by sh95014 on 5/29/23.
//

#import "DebuggerWindowController.h"
#import "AppDelegate.h"
#import "CapsuleView.h"
#import "ConsoleViewController.h"
#import "DisassemblyTableViewController.h"
#import "InspectorOutlineViewController.h"
#import "SymbolTable.h"
#import "NSColor+AppleWin.h"

#import "StdAfx.h"
#import "Core.h"
#import "Debug.h"

#define REFRESH_DELAY               0.1
#define REFRESH_AUTOMATIC           1
#define REFRESH_USER_ACTION         2

#define INSPECTOR_MIN_WIDTH         160

@interface DebuggerWindowController ()

@property (weak) EmulatorViewController *emulatorVC;
@property (assign) BOOL inDebugMode;

@property (weak) IBOutlet NSSplitView *splitView;

@property (weak) IBOutlet NSComboBox *symbolsComboBox;
@property (weak) IBOutlet NSPopUpButton *bookmarksButton;
@property (strong) DisassemblyTableViewController *disassemblyVC;
@property (weak) IBOutlet NSTableView *disassemblyTableView;

@property (strong) InspectorOutlineViewController *inspectorVC;
@property (weak) IBOutlet NSOutlineView *inspectorsOutlineView;

@property (weak) IBOutlet NSButton *toggleRunningButton;
@property (weak) IBOutlet NSButton *singleStepButton;
@property (weak) IBOutlet NSTextField *promptTextField;
@property (weak) IBOutlet NSPopUpButton *themePopUpButton;

@property (strong) ConsoleViewController *consoleVC;
@property (weak) IBOutlet NSTextView *consoleTextView;

@property (strong) NSMutableArray<NSString *> *commandHistory;
@property (strong) NSString *savedPromptText;
@property (assign) NSInteger commandHistoryIndex;

@end

@implementation DebuggerWindowController

- (id)initWithEmulatorVC:(EmulatorViewController *)emulatorVC {
    if ((self = [super init]) != nil) {
        self.inDebugMode = YES;
        self.commandHistory = [NSMutableArray array];
        self.commandHistoryIndex = NSNotFound;
        
        self.emulatorVC = emulatorVC;
        if (![[NSBundle mainBundle] loadNibNamed:@"Debugger" owner:self topLevelObjects:nil]) {
            NSLog(@"failed to load Debugger nib");
            return nil;
        }
        
        [self initCPUPane];
        [self initConsolePane];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
        [center addObserverForName:EmulatorDidEnterDebugModeNotification object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
            self.inDebugMode = YES;
        }];
        [center addObserverForName:EmulatorDidExitDebugModeNotification object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
            self.inDebugMode = NO;
            [self performSelector:@selector(refresh:) withObject:@(REFRESH_AUTOMATIC) afterDelay:REFRESH_DELAY];
        }];
        [center addObserverForName:SymbolTableDidChangeNotification object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
            [self.symbolsComboBox noteNumberOfItemsChanged];
        }];
        
        [self.splitView setPosition:self.splitView.bounds.size.width - INSPECTOR_MIN_WIDTH ofDividerAtIndex:0];
        [self refresh:@(REFRESH_AUTOMATIC)];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)toggleRunningAction:(id)sender {
    if (g_nAppMode == MODE_DEBUG) {
        [self.emulatorVC exitDebugMode];
    }
    else {
        [self.emulatorVC enterDebugMode];
    }
}

- (IBAction)singleStepAction:(id)sender {
    [self.emulatorVC singleStep];
    [self refresh:@(REFRESH_AUTOMATIC)];
}

#pragma mark - NSWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [self.emulatorVC exitDebugMode];
    return YES;
}

#pragma mark - NSTabViewDelegate

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(nullable NSTabViewItem *)tabViewItem {
    if ([tabViewItem.identifier isEqualToString:@"console"]) {
        [self.promptTextField becomeFirstResponder];
    }
}

#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (proposedPosition > splitView.bounds.size.width - INSPECTOR_MIN_WIDTH) {
        return splitView.bounds.size.width - INSPECTOR_MIN_WIDTH;
    }
    return proposedPosition;
}

#pragma mark - NSControlTextEditingDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector {
    if (control == self.promptTextField) {
        if (commandSelector == @selector(insertNewline:)) {
            NSString *cmd = self.promptTextField.stringValue;
            [self sendDebuggerCommand:cmd refresh:YES];
            if (cmd.length > 0 && ![self.commandHistory.firstObject isEqualToString:cmd]) {
                [self.commandHistory insertObject:cmd atIndex:0];
            }
            self.promptTextField.stringValue = @"";
            self.commandHistoryIndex = NSNotFound;
            self.savedPromptText = nil;
            return YES;
        }
        else if (commandSelector == @selector(moveUp:)) {
            // commandHistoryIndex is NSNotFound if the user hasn't pressed [↑], after which it
            // points to the entry in commandHistory that we replaced the prompt text with.
            NSString *cmd = nil;
            if (self.commandHistoryIndex == NSNotFound) {
                if (self.commandHistory.count > 0) {
                    self.commandHistoryIndex = 0;
                    cmd = self.commandHistory.firstObject;
                    self.savedPromptText = self.promptTextField.stringValue;
                }
            }
            else if (self.commandHistoryIndex + 1 < self.commandHistory.count) {
                cmd = self.commandHistory[++self.commandHistoryIndex];
            }
            if (cmd != nil) {
                self.promptTextField.stringValue = cmd;
                [self.promptTextField selectText:nil];
            }
            return YES;
        }
        else if (commandSelector == @selector(moveDown:)) {
            NSString *cmd = nil;
            switch (self.commandHistoryIndex) {
                case NSNotFound:
                    break;
                case 0:
                    cmd = self.savedPromptText;
                    self.commandHistoryIndex = NSNotFound;
                    self.savedPromptText = nil;
                    break;
                default:
                    cmd = self.commandHistory[--self.commandHistoryIndex];
                    break;
            }
            if (cmd != nil) {
                self.promptTextField.stringValue = cmd;
                [self.promptTextField selectText:nil];
            }
            return YES;
        }
    }
    else if (control == self.symbolsComboBox) {
        if (commandSelector == @selector(insertNewline:)) {
            NSInteger index = [self.symbolsComboBox indexOfSelectedItem];
            SymbolTableItem *item = [[SymbolTable sharedTable] itemAtIndex:index];
            if (item != nil) {
                [self.disassemblyVC recenterAtAddress:item.address];
            }
        }
    }
    return NO;
}

#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    return [[SymbolTable sharedTable] totalNumberOfSymbols];;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    return [[SymbolTable sharedTable] itemAtIndex:index].symbol;
}

- (NSUInteger)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)string {
    return [[SymbolTable sharedTable] indexOfSymbol:string];
}

- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)string {
    return [[SymbolTable sharedTable] firstItemWithPrefix:string].symbol;
}

#pragma mark - NSComboBoxDelegate

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSInteger index = [self.symbolsComboBox indexOfSelectedItem];
    SymbolTableItem *item = [[SymbolTable sharedTable] itemAtIndex:index];
    [self.disassemblyVC recenterAtAddress:item.address];
}

#pragma mark - DisassemblyTableViewControllerDelegate, InspectorOutlineViewControllerDelegate

- (void)sendDebuggerCommand:(NSString *)command refresh:(BOOL)shouldRefresh {
    const int savedScheme = g_iColorScheme;
    
    for (const char *cmd = command.UTF8String; *cmd; cmd++) {
        DebuggerInputConsoleChar(*cmd);
    }
    [self.emulatorVC resetSpeed];
    DebuggerProcessKey(VK_RETURN);
    
    if (savedScheme != g_iColorScheme) {
        [self.themePopUpButton selectItemWithTag:g_iColorScheme];
        [self themeDidChange:self];
    }
    else {
        if (shouldRefresh) {
            [self refresh:@(REFRESH_USER_ACTION)];
        }
        [self.consoleVC update];
    }
    [self refreshBookmarks];
}

#pragma mark - Actions

- (IBAction)themeDidChange:(id)sender {
    g_iColorScheme = (int)self.themePopUpButton.selectedTag;
    
    [self configurePrompt];
    
    [self.consoleVC themeDidChange];
    [self.inspectorVC themeDidChange];
    [self refresh:@(REFRESH_USER_ACTION)];
}

- (IBAction)selectBookmark:(id)sender {
    [self.disassemblyVC selectBookmark:self.bookmarksButton.indexOfSelectedItem-1];
    [self.bookmarksButton selectItemAtIndex:0];
}

#pragma mark - Internal

- (void)initCPUPane {
    self.disassemblyVC = [[DisassemblyTableViewController alloc] initWithTableView:self.disassemblyTableView];
    self.disassemblyVC.delegate = self;
    
    self.inspectorVC = [[InspectorOutlineViewController alloc] initWithOutlineView:self.inspectorsOutlineView];
    self.inspectorVC.delegate = self;

    [self configurePrompt];
    
    [self.themePopUpButton removeAllItems];
    [self.themePopUpButton addItemWithTitle:NSLocalizedString(@"Color", @"")];
    self.themePopUpButton.lastItem.tag = SCHEME_COLOR;
    [self.themePopUpButton addItemWithTitle:NSLocalizedString(@"Mono", @"")];
    self.themePopUpButton.lastItem.tag = SCHEME_MONO;
    [self.themePopUpButton addItemWithTitle:NSLocalizedString(@"Black & White", @"")];
    self.themePopUpButton.lastItem.tag = SCHEME_BW;
    [self.themePopUpButton selectItemWithTag:g_iColorScheme];
}

- (void)configurePrompt {
    self.promptTextField.textColor = [NSColor colorForType:NSColorTypeConsoleInputDefault];
    self.promptTextField.backgroundColor = [NSColor colorForType:NSColorTypeConsoleInputDefaultBackground];
    self.promptTextField.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
}

- (void)initConsolePane {
    self.consoleVC = [[ConsoleViewController alloc] initWithTextView:self.consoleTextView];
}

- (void)refresh:(NSNumber *)type {
    [self.disassemblyVC reloadData:type.intValue == REFRESH_AUTOMATIC];
    [self.inspectorVC refresh];
    [self refreshBookmarks];

    if (g_nAppMode == MODE_DEBUG) {
        NSString *toolTip = NSLocalizedString(@"Resume Execution", @"");
        if (@available(macOS 11.0, *)) {
            self.toggleRunningButton.image = [NSImage imageWithSystemSymbolName:@"forward.frame" accessibilityDescription:toolTip];
        }
        else {
            self.toggleRunningButton.title = NSLocalizedString(@"Resume", @"resume execution");
        }
        self.toggleRunningButton.toolTip = toolTip;
        self.toggleRunningButton.state = NSControlStateValueOff;
    }
    else {
        NSString *toolTip = NSLocalizedString(@"Pause Execution", @"");
        if (@available(macOS 11.0, *)) {
            self.toggleRunningButton.image = [NSImage imageWithSystemSymbolName:@"pause" accessibilityDescription:toolTip];
        }
        else {
            self.toggleRunningButton.title = NSLocalizedString(@"Pause", @"pause execution");
        }
        self.toggleRunningButton.toolTip = toolTip;
        self.toggleRunningButton.state = NSControlStateValueOn;
    }
    
    if (!self.inDebugMode) {
        [self performSelector:@selector(refresh:) withObject:@(REFRESH_AUTOMATIC) afterDelay:REFRESH_DELAY];
    }
}

- (void)refreshBookmarks {
    for (NSInteger i = 0; i < MAX_BOOKMARKS; i++) {
        Bookmark_t *bm = g_aBookmarks + i;
        [self.bookmarksButton.menu itemAtIndex:i+1].enabled = bm->bSet;
#ifdef DEBUG
        [self.bookmarksButton.menu itemAtIndex:i+1].title = [NSString stringWithFormat:@"Bookmark %ld ($%04X)", (long)i, bm->nAddress];
#endif
    }
}

@end
