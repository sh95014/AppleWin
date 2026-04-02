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
