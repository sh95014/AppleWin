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

// Objective-C typedefs BOOL to be bool, but wincompat.h typedefs it to be
// int32_t, which causes function signature mismatches (such as with the
// RegLoadValue() calls below.) This hack allows the function to be seen
// with the correct signature and avoids the link error.
#define BOOL int32_t
#import "Registry.h"
#undef BOOL

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
@property (strong) IBOutlet NSButton *saveDiskImageButton;

@property (assign) BOOL defaultToHardDisk;
@property (strong, nullable) NSSavePanel *diskImageSavePanel;

@end

@implementation DiskMakerWindowController

- (id)init {
    return [super initWithWindowNibName:@"DiskMakerWindow"];
}

- (void)selectHardDisk {
    self.defaultToHardDisk = YES;
}

- (void)windowDidLoad {
    if (self.defaultToHardDisk) {
        [self.capacityButton selectItemAtIndex:CAPACITY_32MB];
        [self.formatButton selectItemAtIndex:FORMAT_PRODOS];
    }
    
    uint32_t onFormatCopyProDOS = TRUE;
    uint32_t onFormatCopyBitsyBoot = TRUE;
    uint32_t onFormatCopyBitsyBye = TRUE;
    uint32_t onFormatCopyBASICSYSTEM = TRUE;
    RegLoadValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_PRODOS_SYS, TRUE, &onFormatCopyProDOS);
    RegLoadValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_BITSY_BOOT, TRUE, &onFormatCopyBitsyBoot);
    RegLoadValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_BITSY_BYE, TRUE, &onFormatCopyBitsyBye);
    RegLoadValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_BASIC, TRUE, &onFormatCopyBASICSYSTEM);
    self.onFormatCopyProDOSButton.state = onFormatCopyProDOS ? NSControlStateValueOn : NSControlStateValueOff;
    self.onFormatCopyBitsyBootButton.state = onFormatCopyBitsyBoot ? NSControlStateValueOn : NSControlStateValueOff;
    self.onFormatCopyBitsyByeButton.state = onFormatCopyBitsyBye ? NSControlStateValueOn : NSControlStateValueOff;
    self.onFormatCopyBASICSYSTEMButton.state = onFormatCopyBASICSYSTEM ? NSControlStateValueOn : NSControlStateValueOff;
    
    [super windowDidLoad];
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

- (IBAction)onFormatCopyToggled:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isEqual:self.onFormatCopyProDOSButton]) {
        RegSaveValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_PRODOS_SYS, TRUE, self.onFormatCopyProDOSButton.state == NSControlStateValueOn);
    }
    else if ([sender isEqual:self.onFormatCopyBitsyBootButton]) {
        RegSaveValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_BITSY_BOOT, TRUE, self.onFormatCopyBitsyBootButton.state == NSControlStateValueOn);
    }
    else if ([sender isEqual:self.onFormatCopyBitsyByeButton]) {
        RegSaveValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_BITSY_BYE, TRUE, self.onFormatCopyBitsyByeButton.state == NSControlStateValueOn);
    }
    else if ([sender isEqual:self.onFormatCopyBASICSYSTEMButton]) {
        RegSaveValue(REG_PREFS, REGVALUE_PREF_NEW_DISK_COPY_BASIC, TRUE, self.onFormatCopyBASICSYSTEMButton.state == NSControlStateValueOn);
    }
}

- (IBAction)saveDiskImageAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    const BOOL newDiskCopyProDOS    = (self.onFormatCopyProDOSButton.state == NSControlStateValueOn);
    const BOOL newDiskCopyBitsyBoot = (self.onFormatCopyBitsyBootButton.state == NSControlStateValueOn);
    const BOOL newDiskCopyBitsyBye  = (self.onFormatCopyBitsyByeButton.state == NSControlStateValueOn);
    const BOOL newDiskCopyBASIC     = (self.onFormatCopyBASICSYSTEMButton.state == NSControlStateValueOn);

    const NSInteger capacity = self.capacityButton.indexOfSelectedItem;
    const NSInteger format = self.formatButton.indexOfSelectedItem;
    const BOOL isDOS33     = (format == FORMAT_DOS33 && (capacity == CAPACITY_140KB || capacity == CAPACITY_160KB));
    const BOOL isFloppy    = !(format == FORMAT_PRODOS && (capacity == CAPACITY_800KB || capacity == CAPACITY_32MB));
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
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MMM-dd_HH'h'-MM'm'-ss's'";
    NSString *extension = isHardDisk
        ? @"hdv"
        : isDOS33
            ? @"do"
            : @"po"
            ;
    NSString *filename = [NSString stringWithFormat:@"%@_%@.%@",
        isFloppy ? NSLocalizedString(@"Blank_Floppy", @"blank floppy disk") : NSLocalizedString(@"Blank_Hard", @"blank hard disk"),
        [dateFormatter stringFromDate:[NSDate date]],
        extension
    ];
    
    self.diskImageSavePanel = [NSSavePanel savePanel];
    self.diskImageSavePanel.canCreateDirectories = YES;
    self.diskImageSavePanel.title = NSLocalizedString(@"Save disk image as...", @"");
    self.diskImageSavePanel.nameFieldStringValue = filename;
    
    if ([self.diskImageSavePanel runModal] == NSModalResponseOK) {
        NSURL *url = self.diskImageSavePanel.URL;
        mariani::MarianiFrame *frame = (mariani::MarianiFrame *)theAppDelegate.emulatorVC.frame;
        New_DOSProDOS_Disk("New Disk Image",
                           [url.path cStringUsingEncoding:NSUTF8StringEncoding],
                           diskSize,
                           isDOS33,
                           newDiskCopyBitsyBoot,
                           newDiskCopyBitsyBye,
                           newDiskCopyBASIC,
                           newDiskCopyProDOS,
                           frame);
        self.diskImageSavePanel = nil;
    }
    
    [self.window close];
}

- (IBAction)cancelAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.window close];
}

@end

NS_ASSUME_NONNULL_END
