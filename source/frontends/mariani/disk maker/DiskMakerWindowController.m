//
//  DiskMakerWindowController.mm
//  Mariani
//
//  Created by sh95014 on 6/24/25.
//

#import <Cocoa/Cocoa.h>
#import "DiskMakerWindowController.h"
#import "ProDOS_FileSystem.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiskMakerWindowController()

@property (strong) IBOutlet NSPopUpButton *capacityButton;
enum { CAPACITY_140KB, CAPACITY_160KB, CAPACITY_800KB, CAPACITY_32MB };

@property (strong) IBOutlet NSPopUpButton *formatButton;
enum { FORMAT_BLANK, FORMAT_DOS33, FORMAT_PRODOS };

@property (strong) IBOutlet NSButton *customBootSectorButton;
@property (strong) IBOutlet NSButton *onFormatCopyProDOSButton;
@property (strong) IBOutlet NSButton *onFormatCopyBitsyBootButton;
@property (strong) IBOutlet NSButton *onFormatCopyBitsyByeButton;
@property (strong) IBOutlet NSButton *onFormatCopyBASICSYSTEMButton;
@property (strong) IBOutlet NSButton *createDiskImageButton;

@end

@implementation DiskMakerWindowController

- (id)init {
    if ((self = [super initWithWindowNibName:@"DiskMakerWindow"]) != nil) {
    }
    return self;
}

- (IBAction)capacityChanged:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    // DOS 3.3 can only be on 5.25" disks
    switch (self.capacityButton.indexOfSelectedItem) {
        case CAPACITY_800KB:
        case CAPACITY_32MB:
            if (self.formatButton.indexOfSelectedItem == FORMAT_DOS33) {
                [self.formatButton selectItemAtIndex:FORMAT_BLANK];
            }
    }
}

- (IBAction)formatChanged:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    // DOS 3.3 can only be on 5.25" disks
    if (self.formatButton.indexOfSelectedItem == FORMAT_DOS33) {
        switch (self.capacityButton.indexOfSelectedItem) {
            case CAPACITY_800KB:
            case CAPACITY_32MB:
                [self.capacityButton selectItemAtIndex:CAPACITY_140KB];
        }
    }
}

- (IBAction)createDiskImageAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (IBAction)cancelAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.window close];
}

@end

NS_ASSUME_NONNULL_END
