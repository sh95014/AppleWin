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

- (void)setCard:(Disk2InterfaceCard *)card {
    self->card = card;
    self.thirteenSectorFirmwareButton.state = card->Get13SectorFirmware() ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)loadView {
    [super loadView];
    if (self->card) {
        self.thirteenSectorFirmwareButton.state = card->Get13SectorFirmware() ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

- (IBAction)thirteenSectorFirmwareAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    card->Set13SectorFirmware(self.thirteenSectorFirmwareButton.state == NSControlStateValueOn);
}

@end
