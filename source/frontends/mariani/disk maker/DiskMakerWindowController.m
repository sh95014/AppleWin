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
@property (strong) IBOutlet NSPopUpButton *formatButton;
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

- (IBAction)createDiskImageAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (IBAction)cancelAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.window close];
}

@end

NS_ASSUME_NONNULL_END
