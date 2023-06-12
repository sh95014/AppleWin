//
//  InspectorOutlineViewController.mm
//  Mariani
//
//  Created by sh95014 on 6/1/23.
//

#import "InspectorOutlineViewController.h"
#import "CapsuleView.h"
#import "HexDigitFormatter.h"
#import "NSColor+AppleWin.h"

#import "StdAfx.h"
#import "CPU.h"
#import "Debug.h"
#import "Interface.h"
#import "Memory.h"

#define BOX_LABEL_FONT              [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]

#define REGISTER_FONT_SIZE          13
#define REGISTER_FONT_WEIGHT        NSFontWeightRegular
#define REGISTER_SMALLFONT_SIZE     10
#define REGISTER_FIELD_HEIGHT       21

#define LABEL_MARGIN                2
#define BOX_MARGIN                  6

#define kNumAnnunciators            4 // from Memory.cpp

@implementation NSTextField (Mariani)

- (NSUInteger)hexValue {
    NSScanner *scanner = [NSScanner scannerWithString:self.stringValue];
    unsigned int n;
    if ([scanner scanHexInt:&n]) {
        return n;
    }
    return 0;
}

@end

@interface InspectorOutlineViewController ()

@property (weak) NSOutlineView *outlineView;

@property (strong) NSArray<NSButton *> *psButtons;
@property (strong) NSArray<NSButton *> *annunciatorButtons;

@property (strong) IBOutlet NSBox *registersBox;
@property (strong) IBOutlet NSTextField *registerATextField;
@property (strong) IBOutlet NSTextField *registerXTextField;
@property (strong) IBOutlet NSTextField *registerYTextField;
@property (strong) IBOutlet NSTextField *registerATextLabel;
@property (strong) IBOutlet NSTextField *registerXTextLabel;
@property (strong) IBOutlet NSTextField *registerYTextLabel;
@property (strong) IBOutlet NSTextField *registerPSTextField;
@property (strong) IBOutlet NSTextField *registerPCTextField;
@property (strong) IBOutlet NSTextField *registerSPTextField;
@property (strong) IBOutlet NSButton *psNegativeButton;
@property (strong) IBOutlet NSButton *psOverflowButton;
@property (strong) IBOutlet NSButton *psReservedButton;
@property (strong) IBOutlet NSButton *psBreakButton;
@property (strong) IBOutlet NSButton *psDecimalButton;
@property (strong) IBOutlet NSButton *psInterruptDisableButton;
@property (strong) IBOutlet NSButton *psZeroButton;
@property (strong) IBOutlet NSButton *psCarryButton;

@property (strong) IBOutlet NSBox *annunciatorsBox;
@property (strong) IBOutlet NSButton *annunciator0Button;
@property (strong) IBOutlet NSButton *annunciator1Button;
@property (strong) IBOutlet NSButton *annunciator2Button;
@property (strong) IBOutlet NSButton *annunciator3Button;

@property (strong) IBOutlet NSBox *switchesBox;
@property (strong) IBOutlet CapsuleView *switch50CapsuleView;
@property (strong) IBOutlet CapsuleView *switch52CapsuleView;
@property (strong) IBOutlet CapsuleView *switch54CapsuleView;
@property (strong) IBOutlet CapsuleView *switch56CapsuleView;
@property (strong) IBOutlet CapsuleView *switch5ECapsuleView;
@property (strong) IBOutlet CapsuleView *switch00CapsuleView;
@property (strong) IBOutlet CapsuleView *switch02RCapsuleView;
@property (strong) IBOutlet CapsuleView *switch02WCapsuleView;
@property (strong) IBOutlet CapsuleView *switch0CCapsuleView;
@property (strong) IBOutlet CapsuleView *switch0ECapsuleView;

@property (assign) NSInteger labelRowHeight;

@end

@implementation InspectorOutlineViewController

static NSDictionary *psIconMapping = @{
    @(0x80) : @[ [NSImage imageWithSystemSymbolName:@"n.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"n.square.fill" accessibilityDescription:@""] ],
    @(0x40) : @[ [NSImage imageWithSystemSymbolName:@"v.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"v.square.fill" accessibilityDescription:@""] ],
    @(0x20) : @[ [NSImage imageWithSystemSymbolName:@"dot.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"dot.square.fill" accessibilityDescription:@""] ],
    @(0x10) : @[ [NSImage imageWithSystemSymbolName:@"b.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"b.square.fill" accessibilityDescription:@""] ],
    @(0x08) : @[ [NSImage imageWithSystemSymbolName:@"d.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"d.square.fill" accessibilityDescription:@""] ],
    @(0x04) : @[ [NSImage imageWithSystemSymbolName:@"i.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"i.square.fill" accessibilityDescription:@""] ],
    @(0x02) : @[ [NSImage imageWithSystemSymbolName:@"z.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"z.square.fill" accessibilityDescription:@""] ],
    @(0x01) : @[ [NSImage imageWithSystemSymbolName:@"c.square" accessibilityDescription:@""],
                 [NSImage imageWithSystemSymbolName:@"c.square.fill" accessibilityDescription:@""] ],
};

static NSDictionary *annunciatorIconMapping = @{
    @(0) : @[ [NSImage imageWithSystemSymbolName:@"0.circle" accessibilityDescription:@""],
              [NSImage imageWithSystemSymbolName:@"0.circle.fill" accessibilityDescription:@""] ],
    @(1) : @[ [NSImage imageWithSystemSymbolName:@"1.circle" accessibilityDescription:@""],
              [NSImage imageWithSystemSymbolName:@"1.circle.fill" accessibilityDescription:@""] ],
    @(2) : @[ [NSImage imageWithSystemSymbolName:@"2.circle" accessibilityDescription:@""],
              [NSImage imageWithSystemSymbolName:@"2.circle.fill" accessibilityDescription:@""] ],
    @(3) : @[ [NSImage imageWithSystemSymbolName:@"3.circle" accessibilityDescription:@""],
              [NSImage imageWithSystemSymbolName:@"3.circle.fill" accessibilityDescription:@""] ],
};

static NSArray *appleIIeCharacters = @[
    @"␠",    @"!", @"\"", @"#", @"$", @"%", @"&", @"'", @"(", @")", @"*", @"+", @",",  @"-", @".", @"/",
    @"0",    @"1", @"2",  @"3", @"4", @"5", @"6", @"7", @"8", @"9", @":", @";", @"<",  @"=", @">", @"?",
    @"@",    @"a", @"b",  @"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l",  @"m", @"n", @"o",
    @"p",    @"q", @"r",  @"s", @"t", @"u", @"v", @"w", @"x", @"y", @"z", @"[", @"\\", @"]", @"^", @"_",
    @"NBSP", @"╵", @"╴",  @"╷", @"╶", @"┘", @"┐", @"┌", @"└", @"─", @"│", @"┴", @"┤",  @"┬", @"├", @"┼",
    @"◤",    @"◥", @"▒",  @"▘", @"▝", @"▀", @"▖", @"▗", @"▚", @"▌", @"",  @"",  @"←",  @"↑", @"→", @"↓",
    @"`",    @"A", @"B",  @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L",  @"M", @"N", @"O",
    @"P",    @"Q", @"R",  @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", @"{", @"|",  @"}", @"~", @"",
    @"@",    @"A", @"B",  @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L",  @"M", @"N", @"O",
    @"P",    @"Q", @"R",  @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", @"[", @"\\", @"]", @"^", @"_",
    @"␠",    @"!", @"\"", @"#", @"$", @"%", @"&", @"'", @"(", @")", @"*", @"+", @",",  @"-", @".", @"/",
    @"0",    @"1", @"2",  @"3", @"4", @"5", @"6", @"7", @"8", @"9", @":", @";", @"<",  @"=", @">", @"?",
    @"@",    @"A", @"B",  @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L",  @"M", @"N", @"O",
    @"P",    @"Q", @"R",  @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", @"[", @"\\", @"]", @"^", @"_",
    @"␠",    @"!", @"\"", @"#", @"$", @"%", @"&", @"'", @"(", @")", @"*", @"+", @",",  @"-", @".", @"/",
    @"0",    @"1", @"2",  @"3", @"4", @"5", @"6", @"7", @"8", @"9", @":", @";", @"<",  @"=", @">", @"?"
];

static NSDictionary<NSNumber *, NSNumber *> *tagToColorMapping = @{
    @(1) : @(NSColorTypeSwitchAddress),
    @(2) : @(NSColorTypeRegisterLabel),
    @(3) : @(NSColorTypeSwitchLabel),
    @(4) : @(NSColorTypeSwitchLabelWrite),
};

- (id)initWithOutlineView:(NSOutlineView *)outlineView {
    if ((self = [super init]) != nil) {
        self.view = self.outlineView = outlineView;
        self.outlineView.dataSource = self;
        self.outlineView.delegate = self;
        
        self.outlineView.indentationPerLevel = 0;
        
        if (![[NSBundle mainBundle] loadNibNamed:@"InspectorPanels" owner:self topLevelObjects:nil]) {
            NSLog(@"failed to load About nib");
            return nil;
        }
        
        // The order is relevant, mapping to the bit order in the Program Status register
        self.psButtons = @[
            self.psNegativeButton, self.psOverflowButton, self.psReservedButton, self.psBreakButton,
            self.psDecimalButton, self.psInterruptDisableButton, self.psZeroButton, self.psCarryButton
        ];
        
        self.annunciatorButtons = @[
            self.annunciator0Button, self.annunciator1Button, self.annunciator2Button, self.annunciator3Button
        ];
        
        [self configureRegisters];
        [self configureAnnunciators];
        [self configureSwitches];
        
        [self.outlineView expandItem:nil expandChildren:YES];
    }
    return self;
}

- (void)themeDidChange {
    [self configureRegisters];
    [self configureAnnunciators];
    [self configureSwitches];
}

#pragma mark - NSOutlineViewDataSource

static NSArray *topLevelLabels = @[
    NSLocalizedString(@"Registers", @""),
    [NSNull null],
    NSLocalizedString(@"Annunciators", @""),
    [NSNull null],
    NSLocalizedString(@"Switches C0xx", @""),
];

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return topLevelLabels.count;
    }
    else if (item == [NSNull null]) {
        return 0;
    }
    else {
        return 1;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        if (topLevelLabels[index] != [NSNull null]) {
            return @(index);
        }
        else {
            return [NSNull null];
        }
    }
    else if ([item isKindOfClass:[NSNumber class]]) {
        return @[ self.registersBox, @"", self.annunciatorsBox, @"", self.switchesBox ][[item intValue]];
    }
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isKindOfClass:[NSNumber class]];
}

#pragma mark - NSOutlineViewDelegate

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    if ([item isKindOfClass:[NSNumber class]]) {
        if (self.labelRowHeight == 0) {
            self.labelRowHeight = BOX_LABEL_FONT.boundingRectForFont.size.height + LABEL_MARGIN;
        }
        return self.labelRowHeight;
    }
    else if (item == [NSNull null]) {
        return BOX_MARGIN;
    }
    else if ([item isKindOfClass:[NSView class]]) {
        NSView *view = (NSView *)item;
        return view.bounds.size.height;
    }
    return 0;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item isKindOfClass:[NSNumber class]]) {
        // cheap hack to give space to the disclosure icon
        NSString *label = [NSString stringWithFormat:@"  %@", topLevelLabels[[item intValue]]];
        
        NSTextField *textField = [NSTextField textFieldWithString:label];
        textField.editable = NO;
        textField.selectable = NO;
        textField.bezeled = NO;
        textField.textColor = [NSColor textColor];
        textField.backgroundColor = nil;
        textField.font = BOX_LABEL_FONT;
        
        return textField;
    }
    else if ([item isKindOfClass:[NSView class]]) {
        return item;
    }
    return nil;
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if ([obj.object isKindOfClass:[NSTextField class]]) {
        NSTextField *textField = (NSTextField *)obj.object;
        NSString *cmd = nil;
        if (textField == self.registerATextField && [textField hexValue] != regs.a) {
            cmd = [NSString stringWithFormat:@"r a %@", textField.stringValue];
        }
        else if (textField == self.registerXTextField && [textField hexValue] != regs.x) {
            cmd = [NSString stringWithFormat:@"r x %@", textField.stringValue];
        }
        else if (textField == self.registerYTextField && [textField hexValue] != regs.y) {
            cmd = [NSString stringWithFormat:@"r y %@", textField.stringValue];
        }
        else if (textField == self.registerPCTextField && [textField hexValue] != regs.pc) {
            cmd = [NSString stringWithFormat:@"r pc %@", textField.stringValue];
        }
        else if (textField == self.registerSPTextField && [textField hexValue] != regs.sp) {
            cmd = [NSString stringWithFormat:@"r s %@", textField.stringValue];
        }
        if (cmd != nil && [self.delegate respondsToSelector:@selector(sendDebuggerCommand:refresh:)]) {
            [self.delegate sendDebuggerCommand:cmd refresh:YES];
            [self refresh];
        }
    }
}

#pragma mark - Actions

- (IBAction)psBitAction:(id)sender {
    NSString *cmd = nil;
    NSInteger index = [self.psButtons indexOfObject:sender];
    if (index != NSNotFound) {
        unichar flagName = [@"nvrbdizc" characterAtIndex:index];
        if (regs.ps & (1 << (7 - index))) {
            cmd = [NSString stringWithFormat:@"cl%c", flagName];
        }
        else {
            cmd = [NSString stringWithFormat:@"se%c", flagName];
        }
    }
    if (cmd != nil && [self.delegate respondsToSelector:@selector(sendDebuggerCommand:refresh:)]) {
        [self.delegate sendDebuggerCommand:cmd refresh:YES];
    }
}

#pragma mark - Internal

- (void)configureRegisters {
    self.registersBox.fillColor = [NSColor colorForType:NSColorTypeRegistersBackground];
    [self colorTaggedLabels:self.registersBox];
    
    [self configureRegisterTextField:self.registerATextField type:NSColorTypeRegisterValue maxLength:2];
    [self configureRegisterTextField:self.registerXTextField type:NSColorTypeRegisterValue maxLength:2];
    [self configureRegisterTextField:self.registerYTextField type:NSColorTypeRegisterValue maxLength:2];
    [self configureRegisterTextLabel:self.registerATextLabel type:NSColorTypeRegisterCharacterValue];
    [self configureRegisterTextLabel:self.registerXTextLabel type:NSColorTypeRegisterCharacterValue];
    [self configureRegisterTextLabel:self.registerYTextLabel type:NSColorTypeRegisterCharacterValue];
    [self configureRegisterTextField:self.registerPSTextField type:NSColorTypeRegisterValue maxLength:2];
    [self configureRegisterTextField:self.registerPCTextField type:NSColorTypeRegisterValue maxLength:4];
    [self configureRegisterTextField:self.registerSPTextField type:NSColorTypeRegisterValue maxLength:4];
    
    for (NSButton *button in self.psButtons) {
        button.contentTintColor = [NSColor colorForType:NSColorTypePSRegister];
    }
}

- (void)configureAnnunciators {
    self.annunciatorsBox.fillColor = [NSColor colorForType:NSColorTypeAnnunciatorBackground];
    
    for (NSButton *button in self.annunciatorButtons) {
        button.contentTintColor = [NSColor colorForType:NSColorTypeAnnunciator];
    }
}

- (void)configureRegisterTextField:(NSTextField *)textField type:(NSColorTypeMariani)type maxLength:(NSUInteger)maxLength {
    textField.font = [NSFont monospacedDigitSystemFontOfSize:REGISTER_FONT_SIZE weight:REGISTER_FONT_WEIGHT];
    textField.textColor = [NSColor colorForType:type];
    textField.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    textField.formatter = [[HexDigitFormatter alloc] initWithMaxLength:maxLength];
    textField.delegate = self;
}

- (void)configureRegisterTextLabel:(NSTextField *)label type:(NSColorTypeMariani)type {
    label.font = [NSFont monospacedSystemFontOfSize:REGISTER_FONT_SIZE weight:REGISTER_FONT_WEIGHT];
    label.textColor = [NSColor colorForType:type];
}

- (void)refreshLabel:(NSTextField *)label value:(NSInteger)value with:(NSTextField *)textField {
    NSString *character = appleIIeCharacters[value];
    label.stringValue = [NSString stringWithFormat:@"%@", character];
    CGFloat fontHeight;
    if (character.length == 1) {
        label.font = [NSFont monospacedSystemFontOfSize:REGISTER_FONT_SIZE weight:REGISTER_FONT_WEIGHT];
        label.wantsLayer = NO;
        label.layer.borderWidth = 0;
        label.alignment = NSTextAlignmentNatural;
        fontHeight = label.font.boundingRectForFont.size.height;
    }
    else {
        label.font = [NSFont monospacedSystemFontOfSize:REGISTER_SMALLFONT_SIZE weight:REGISTER_FONT_WEIGHT];
        label.wantsLayer = YES;
        label.layer.borderColor = label.textColor.CGColor;
        label.layer.borderWidth = 1.0;
        label.layer.cornerRadius = 5.0;
        label.alignment = NSTextAlignmentCenter;
        fontHeight = label.font.ascender + 3;
    }
    
    CGRect frame = label.frame;
    frame.size.height = fontHeight;
    frame.origin.y = floorf(CGRectGetMidY(textField.frame) - fontHeight / 2);
    label.frame = frame;
}

- (void)configureSwitches {
    self.switchesBox.fillColor = [NSColor colorForType:NSColorTypeSwitchesBackground];
    
    self.switch50CapsuleView.titles = @[ @"GR", @"TEXT" ];
    self.switch52CapsuleView.titles = @[ @"FULL", @"MIX" ];
    self.switch54CapsuleView.titles = @[ @"1", @"2" ];
    self.switch56CapsuleView.titles = @[ @"LO", @"HIRES" ];
    self.switch5ECapsuleView.titles = @[ @"DHGR", @"HGR" ];
    self.switch00CapsuleView.titles = @[ @"0", @"1" ];
    self.switch02RCapsuleView.titles = @[ @"m", @"x" ];
    self.switch02WCapsuleView.titles = @[ @"m", @"x" ];
    self.switch0CCapsuleView.titles = @[ @"40", @"80" ];
    self.switch0ECapsuleView.titles = @[ @"ASC", @"MOUS" ];
    
    [self configureSwitchView:self.switch50CapsuleView];
    [self configureSwitchView:self.switch52CapsuleView];
    [self configureSwitchView:self.switch54CapsuleView];
    [self configureSwitchView:self.switch56CapsuleView];
    [self configureSwitchView:self.switch5ECapsuleView];
    [self configureSwitchView:self.switch00CapsuleView];
    [self configureSwitchView:self.switch02RCapsuleView];
    [self configureSwitchView:self.switch02WCapsuleView];
    [self configureSwitchView:self.switch0CCapsuleView];
    [self configureSwitchView:self.switch0ECapsuleView];
    
    [self colorTaggedLabels:self.switchesBox];
}

- (void)configureSwitchView:(CapsuleView *)capsuleView {
    NSDictionary *attributes = @{
        NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]],
        NSForegroundColorAttributeName : [NSColor colorForType:NSColorTypeSwitch],
    };
    capsuleView.color = [NSColor colorForType:NSColorTypeSwitch];
    capsuleView.backgroundColor = [NSColor colorForType:NSColorTypeSwitchBackground];
    capsuleView.attributes = attributes;
}

- (void)colorTaggedLabels:(NSView *)view {
    if (view.tag != 0 && [view isKindOfClass:[NSTextField class]]) {
        NSTextField *textField = (NSTextField *)view;
        NSNumber *value = tagToColorMapping[@(view.tag)];
        if (value == nil) {
            NSLog(@"%@ has invalid tag", view);
        }
        else {
            textField.textColor = [NSColor colorForType:(NSColorTypeMariani)value.intValue];
        }
    }
    for (NSView *subview in view.subviews) {
        [self colorTaggedLabels:subview];
    }
}

- (void)refresh {
    self.registerATextField.stringValue = [NSString stringWithFormat:@"%02X", regs.a];
    self.registerXTextField.stringValue = [NSString stringWithFormat:@"%02X", regs.x];
    self.registerYTextField.stringValue = [NSString stringWithFormat:@"%02X", regs.y];
    [self refreshLabel:self.registerATextLabel value:regs.a with:self.registerATextField];
    [self refreshLabel:self.registerXTextLabel value:regs.x with:self.registerXTextField];
    [self refreshLabel:self.registerYTextLabel value:regs.y with:self.registerYTextField];
    self.registerPSTextField.stringValue = [NSString stringWithFormat:@"%02X", regs.ps];
    self.registerPCTextField.stringValue = [NSString stringWithFormat:@"%04X", regs.pc];
    self.registerSPTextField.stringValue = [NSString stringWithFormat:@"%04X", regs.sp];
    
    for (NSInteger i = 0; i < self.psButtons.count; i++) {
        const NSUInteger bit = 1 << (7 - i);
        const BOOL value = (regs.ps & bit) != 0;
        NSButton *bitButton = self.psButtons[i];
        NSArray *icons = psIconMapping[@(bit)];
        bitButton.image = icons[value];
    }
    
    for (NSInteger i = 0; i < kNumAnnunciators; i++) {
        NSButton *annunciatorButton = self.annunciatorButtons[i];
        NSArray *icons = annunciatorIconMapping[@(i)];
        annunciatorButton.image = icons[MemGetAnnunciator((UINT)i)];
    }
    
    Video & video = GetVideo();
    self.switch50CapsuleView.selectedIndex = video.VideoGetSWTEXT();
    self.switch52CapsuleView.selectedIndex = video.VideoGetSWMIXED();
    self.switch54CapsuleView.selectedIndex = video.VideoGetSWPAGE2();
    self.switch56CapsuleView.selectedIndex = video.VideoGetSWHIRES();
    self.switch5ECapsuleView.selectedIndex = video.VideoGetSWDHIRES();
    self.switch00CapsuleView.selectedIndex = video.VideoGetSW80STORE();
    self.switch02RCapsuleView.selectedIndex = (GetMemMode() & MF_AUXREAD) ? 1 : 0;
    self.switch02WCapsuleView.selectedIndex = (GetMemMode() & MF_AUXWRITE) ? 1 : 0;
    self.switch0CCapsuleView.selectedIndex = video.VideoGetSW80COL();
    self.switch0ECapsuleView.selectedIndex = video.VideoGetSWAltCharSet();
}

@end
