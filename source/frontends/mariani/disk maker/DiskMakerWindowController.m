//
//  DiskMakerWindowController.mm
//  Mariani
//
//  Created by sh95014 on 6/24/25.
//

#import <Cocoa/Cocoa.h>
#import <string>
#import "AppDelegate.h"
#import "DiskMakerWindowController.h"

#import "windows.h"
#import <vector>
#import "DiskImageHelper.h"
#import "ProDOS_FileSystem.h"
#import "ProDOS_Utils.h"
#import "StrFormat.h"
#import "MarianiFrame.h"

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
        case CAPACITY_800KB: // fallthrough
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
            case CAPACITY_800KB: // fallthrough
            case CAPACITY_32MB:
                [self.capacityButton selectItemAtIndex:CAPACITY_140KB];
        }
    }
}

- (IBAction)createDiskImageAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    const BOOL newDiskCopyProDOS    = (self.onFormatCopyProDOSButton.state == NSControlStateValueOn);
    const BOOL newDiskCopyBitsyBoot = (self.onFormatCopyBitsyBootButton.state == NSControlStateValueOn);
    const BOOL newDiskCopyBitsyBye  = (self.onFormatCopyBitsyByeButton.state == NSControlStateValueOn);
    const BOOL newDiskCopyBASIC     = (self.onFormatCopyBASICSYSTEMButton.state == NSControlStateValueOn);

    const NSInteger capacity = self.capacityButton.indexOfSelectedItem;
    const NSInteger format = self.formatButton.indexOfSelectedItem;
    const BOOL isDOS33     = (format == FORMAT_DOS33 && (capacity == CAPACITY_140KB || capacity == CAPACITY_160KB));
    const BOOL isFloppy    = !(format == FORMAT_PRODOS && (capacity == CAPACITY_800KB || capacity == CAPACITY_32MB));
    const BOOL isFloppy525 = ((format == FORMAT_DOS33 && (capacity == CAPACITY_140KB || capacity == CAPACITY_160KB)) || isDOS33);
    const BOOL is40Track   = ((format == FORMAT_DOS33 || format == FORMAT_PRODOS) && capacity == CAPACITY_160KB);
    const BOOL isUnidisk35 = (format == FORMAT_PRODOS && capacity == CAPACITY_800KB);
    const BOOL isHardDisk  = (format == FORMAT_PRODOS && capacity == CAPACITY_32MB);
    const size_t diskSize  = isHardDisk
                                ? HARDDISK_32M_SIZE
                                : isUnidisk35
                                  ? UNIDISK35_800K_SIZE
                                  : is40Track
                                    ? TRACK_DENIBBLIZED_SIZE * TRACKS_MAX
                                    : TRACK_DENIBBLIZED_SIZE * TRACKS_STANDARD
                                    ;
    time_t timestamp = time( NULL );
    tm datetime = *localtime(&timestamp);
    
    const size_t MAX_MONTH_LEN = 32;
    int   year               = datetime.tm_year + 1900;
    char  mon[MAX_MONTH_LEN] = {0};
    int   day                = datetime.tm_mday;
    int   hour               = datetime.tm_hour;
    int   min                = datetime.tm_min;
    int   sec                = datetime.tm_sec;
    strftime( mon, MAX_MONTH_LEN-1, "%b", &datetime );
    
    std::string sExtension = isHardDisk
        ? ".hdv"
        : isDOS33
          ? ".do"
          : ".po"
            ;
    
    std::string pathname(StrFormat(
          "/Users/sh95014/Desktop/blank_%s_%04d_%3s_%02d_%02dh_%02dm_%02ds%s"
        , isFloppy ? "floppy" : "hard"
        , year, mon, day, hour, min, sec
        , sExtension.c_str()
    ));
    
    mariani::MarianiFrame *frame = (mariani::MarianiFrame *)theAppDelegate.emulatorVC.frame;
    New_DOSProDOS_Disk("New Disk Image", pathname, diskSize, isDOS33, newDiskCopyBitsyBoot, newDiskCopyBitsyBye, newDiskCopyBASIC, newDiskCopyProDOS, frame);
}

- (IBAction)cancelAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.window close];
}

@end

NS_ASSUME_NONNULL_END
