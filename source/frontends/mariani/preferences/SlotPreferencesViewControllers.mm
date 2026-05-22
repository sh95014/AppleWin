//
//  SlotPreferencesViewControllers.m
//  Mariani
//
//  Created by sh95014 on 4/2/26.
//

#import "SlotPreferencesViewControllers.h"
#import "AppDelegate.h"
#import "DiskMakerWindowController.h"
#import "Uthernet2.h"

@interface DiskIIPreferencesViewController ()
@property (strong) IBOutlet NSButton *thirteenSectorFirmwareButton;
@end

@implementation DiskIIPreferencesViewController {
    Disk2InterfaceCard *card;
}

- (void)loadView {
    [super loadView];
    if (self->card) {
        self.thirteenSectorFirmwareButton.state = card->Get13SectorFirmware() ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

- (void)setCard:(Disk2InterfaceCard *)card {
    self->card = card;
    self.thirteenSectorFirmwareButton.state = card->Get13SectorFirmware() ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)thirteenSectorFirmwareAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    card->Set13SectorFirmware(self.thirteenSectorFirmwareButton.state == NSControlStateValueOn);
}

@end

#pragma mark -

@interface HardDiskPreferencesViewController ()
@property (strong) IBOutlet NSTableView *hardDisksTableView;
@property (strong) IBOutlet NSButton *addButton;
@property (strong) IBOutlet NSButton *deleteButton;
@property (strong) DiskMakerWindowController *diskMakerWC;
@end

@implementation HardDiskPreferencesViewController {
    HarddiskInterfaceCard *card;
}

- (void)loadView {
    [super loadView];
    if (self->card) {
        self.hardDisksTableView.delegate = self;
        self.hardDisksTableView.dataSource = self;
        [self.hardDisksTableView deselectAll:self];
        [self updateButtons];
    }
}

- (void)viewWillDisappear {
    [self.diskMakerWC close];
}

- (void)setCard:(HarddiskInterfaceCard *)card {
    self->card = card;
    [self updateButtons];
}

- (IBAction)addAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.canDownloadUbiquitousContents = YES;
    panel.message = NSLocalizedString(@"Select hard disk image", @"");
    panel.prompt = NSLocalizedString(@"Connect", @"");
    panel.delegate = self;

    if ([panel runModal] == NSModalResponseOK) {
        const char *fileSystemRepresentation = panel.URL.fileSystemRepresentation;
        std::string pathname(fileSystemRepresentation);
        int hddIndex;
        if (self.hardDisksTableView.selectedRow >= 0) {
            hddIndex = (int)self.hardDisksTableView.selectedRow;
            NSAssert(hddIndex >= HARDDISK_1 && hddIndex < NUM_HARDDISKS, @"selection was out of range");
        }
        else {
            // find the first empty slot
            for (hddIndex = 0; hddIndex < NUM_HARDDISKS; hddIndex++) {
                if (card->HarddiskGetFullPathName(hddIndex).empty()) {
                    break;
                }
            }
            NSAssert(hddIndex < NUM_HARDDISKS, @"add button should not have been enabled");
        }
        if (card->Insert(hddIndex, pathname)) {
            NSLog(@"Loaded '%s' as HDD %d", fileSystemRepresentation, hddIndex);
            [self.hardDisksTableView reloadData];
            [self updateButtons];
            [theAppDelegate reconfigureDrives];
        }
        else {
            NSLog(@"Failed to '%s' as HDD", fileSystemRepresentation);
        }
    }
}

- (IBAction)deleteAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (self.hardDisksTableView.selectedRow >= 0) {
        int hddIndex = (int)self.hardDisksTableView.selectedRow;
        NSAssert(hddIndex >= HARDDISK_1 && hddIndex < NUM_HARDDISKS, @"selection was out of range");
        NSAssert(!card->HarddiskGetFullPathName(hddIndex).empty(), @"delete sent to empty slot");
        card->Unplug(hddIndex);
        [self.hardDisksTableView reloadData];
        [self updateButtons];
        [theAppDelegate reconfigureDrives];
    }
}

- (IBAction)createAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    self.diskMakerWC = [[DiskMakerWindowController alloc] init];
    [self.diskMakerWC selectHardDisk];
    [self.diskMakerWC showWindow:self];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return NUM_HARDDISKS;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result = [tableView makeViewWithIdentifier:@"HardDiskTableCellView" owner:self];
    if (card != nil) {
        NSString *hddImagePath = [NSString stringWithUTF8String:card->HarddiskGetFullPathName((int)row).c_str()];
        if (hddImagePath.length == 0) {
            hddImagePath = NSLocalizedString(@"—", @"empty slot");
        }
        result.textField.stringValue = hddImagePath;
    }
    else {
        result.textField.stringValue = NSLocalizedString(@"—", @"empty slot");
    }
    return result;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateButtons];
}

- (void)updateButtons {
    NSInteger selectedRow = self.hardDisksTableView.selectedRow;
    if (selectedRow < 0) {
        int count = 0;
        for (int i = HARDDISK_1; i < NUM_HARDDISKS; i++) {
            count += !card->HarddiskGetFullPathName(i).empty();
        }
        
        // with no selection, enable "+" button if an empty slot is available
        self.addButton.enabled = (count < NUM_HARDDISKS);
        // with no selection, nothing to delete
        self.deleteButton.enabled = NO;
    }
    else {
        // always enable "+" button to add image to empty slot or replace image in filled slot
        self.addButton.enabled = YES;
        // enable "-" button if slot is filled
        self.deleteButton.enabled = !card->HarddiskGetFullPathName((int)selectedRow).empty();
    }
}

@end

#pragma mark -

@interface MockingboardPreferencesViewController ()
@property (strong) IBOutlet NSPopUpButton *mainSSI263Button;
@property (strong) IBOutlet NSPopUpButton *unusedSSI263Button;
@property (strong) IBOutlet NSButton *sc01Button;
@end

@implementation MockingboardPreferencesViewController {
    MockingboardCard *card;
}

- (void)loadView {
    [super loadView];
    if (self->card) {
        // NOTE: this requires the options defined in the storyboard to match the
        //       order in SSI263Type exactly!
        [self.mainSSI263Button selectItemAtIndex:card->GetSocketSSI263(self.mainSSI263Button.tag)];
        [self.unusedSSI263Button selectItemAtIndex:card->GetSocketSSI263(self.unusedSSI263Button.tag)];
        self.sc01Button.state = card->GetSocketSC01() ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

- (void)setCard:(MockingboardCard *)card {
    self->card = card;
    [self.mainSSI263Button selectItemAtIndex:card->GetSocketSSI263(self.mainSSI263Button.tag)];
    [self.unusedSSI263Button selectItemAtIndex:card->GetSocketSSI263(self.unusedSSI263Button.tag)];
    self.sc01Button.state = card->GetSocketSC01() ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)ssi263Action:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *button = (NSPopUpButton *)sender;
        
        // NOTE: the socket is stored in the button's tag!
        NSAssert(button.tag == 0 || button.tag == 1, @"");
        card->SetSocketSSI263(button.tag, (SSI263Type)button.indexOfSelectedItem);
    }
}

- (IBAction)sc01Action:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)sender;
        
        card->SetSocketSC01(button.state == NSControlStateValueOn ? SC01 : SSI263Empty);
    }
}

@end

#pragma mark -

@interface SliderPreferencesViewController ()
@property (strong) IBOutlet NSSlider *memorySizeSlider;
@end

@implementation SliderPreferencesViewController

- (void)centerView:(NSView *)view underTick:(NSInteger)tick {
    const NSOperatingSystemVersion macOS26 = { 26, 0, 0 };
    const NSInteger tickIndex = tick - self.memorySizeSlider.minValue;
    const NSRect sliderFrame = self.memorySizeSlider.frame;
    
    // unfortunately, rectOfTickMarkAtIndex: seems to be broken at least in macOS26
    CGFloat tickPosition;
    if ([theAppDelegate.processInfo isOperatingSystemAtLeastVersion:macOS26]) {
        const CGFloat margin = 9;
        const CGFloat tickWidth = 2;
        const CGFloat tickGap = (CGRectGetWidth(sliderFrame) - margin * 2 - tickWidth * self.memorySizeSlider.numberOfTickMarks) / (self.memorySizeSlider.numberOfTickMarks - 1);
        tickPosition = CGRectGetMinX(sliderFrame) + margin + tickIndex * (tickGap + tickWidth) + tickWidth / 2;
    }
    else {
        tickPosition = CGRectGetMinX(sliderFrame) + CGRectGetMidX([self.memorySizeSlider rectOfTickMarkAtIndex:tickIndex]);
    }
    
    // center the frame at the tick mark...
    NSRect viewFrame = view.frame;
    viewFrame.origin.x = tickPosition - CGRectGetWidth(viewFrame) / 2;
    
    // ...but don't exceed the left or right edge of the slider
    if (CGRectGetMinX(viewFrame) < CGRectGetMinX(sliderFrame)) {
        viewFrame.origin.x = sliderFrame.origin.x;
    }
    else if (CGRectGetMaxX(viewFrame) > CGRectGetMaxX(sliderFrame)) {
        viewFrame.origin.x = floorf(CGRectGetMaxX(sliderFrame) - CGRectGetWidth(viewFrame));
    }
    
    view.frame = viewFrame;
}

@end

#pragma mark -

@interface RamWorksPreferencesViewController ()
@property (strong) IBOutlet NSTextField *oneMBLabel;
@property (strong) IBOutlet NSTextField *twoMBLabel;
@property (strong) IBOutlet NSTextField *fourMBLabel;
@property (strong) IBOutlet NSTextField *eightMBLabel;
@property (strong) IBOutlet NSTextField *sixteenMBLabel;
@end

@implementation RamWorksPreferencesViewController

- (void)loadView {
    [super loadView];
    const unsigned banks = GetRamWorksMemorySize();
    self.memorySizeSlider.intValue = banks / 16; // 64 KB per bank
    
    [self centerView:self.oneMBLabel underTick:1];
    [self centerView:self.twoMBLabel underTick:2];
    [self centerView:self.fourMBLabel underTick:4];
    [self centerView:self.eightMBLabel underTick:8];
    [self centerView:self.sixteenMBLabel underTick:16];
}

- (IBAction)memorySliderAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    SetRamWorksMemorySize(self.memorySizeSlider.intValue * 16); // 64 KB per bank
}

@end

#pragma mark -

@interface Saturn128KPreferencesViewController ()
@property (strong) IBOutlet NSTextField *sixteenKBLabel;
@property (strong) IBOutlet NSTextField *thirtyTwoKBLabel;
@property (strong) IBOutlet NSTextField *sixtyFourKBLabel;
@property (strong) IBOutlet NSTextField *oneHundredTwentyEightKBLabel;
@end

@implementation Saturn128KPreferencesViewController

- (void)loadView {
    [super loadView];
    self.memorySizeSlider.enabled = NO; // https://github.com/audetto/AppleWin/issues/400
    
    [self centerView:self.sixteenKBLabel underTick:1];
    [self centerView:self.thirtyTwoKBLabel underTick:2];
    [self centerView:self.sixtyFourKBLabel underTick:4];
    [self centerView:self.oneHundredTwentyEightKBLabel underTick:8];
}

- (IBAction)memorySliderAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    // https://github.com/audetto/AppleWin/issues/400
}

@end

#pragma mark -

@interface UthernetPreferencesViewController ()
@property (strong) IBOutlet NSButton *virtualDNSButton;
@end

@implementation UthernetPreferencesViewController

- (void)loadView {
    [super loadView];
    self.virtualDNSButton.state = Uthernet2::GetRegistryVirtualDNS(self.slot) ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)virtualDNSAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    Uthernet2::SetRegistryVirtualDNS(self.slot, self.virtualDNSButton.state == NSControlStateValueOn);
}

@end
