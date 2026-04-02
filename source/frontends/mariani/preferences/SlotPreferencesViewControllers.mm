//
//  SlotPreferencesViewControllers.m
//  Mariani
//
//  Created by sh95014 on 4/2/26.
//

#import "SlotPreferencesViewControllers.h"

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

@interface RamWorksPreferencesViewController ()
@property (strong) IBOutlet NSSlider *memorySizeSlider;
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

- (void)centerView:(NSView *)view underTick:(NSInteger)tick {
    const NSInteger tickIndex = tick - self.memorySizeSlider.minValue;
    const NSRect sliderFrame = self.memorySizeSlider.frame;
    NSRect tickFrame = [self.memorySizeSlider rectOfTickMarkAtIndex:tickIndex];
    tickFrame.origin.x += sliderFrame.origin.x;
    tickFrame.origin.y += sliderFrame.origin.y;
    
    // center the frame at the tick mark...
    NSRect viewFrame = view.frame;
    viewFrame.origin.x = floorf(CGRectGetMidX(tickFrame) - CGRectGetWidth(tickFrame) / 2);
    
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
