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
#import "CardManager.h"
#import "CmdLine.h"
#import "Disk.h"
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
@property (strong) IBOutlet NSButton *clearCustomBootSectorButton;
@property (strong, nullable) NSOpenPanel *customBootSectorOpenPanel;

@property (strong) IBOutlet NSButton *onFormatCopyProDOSButton;
@property (strong) IBOutlet NSButton *onFormatCopyBitsyBootButton;
@property (strong) IBOutlet NSButton *onFormatCopyBitsyByeButton;
@property (strong) IBOutlet NSButton *onFormatCopyBASICSYSTEMButton;

@property (strong) IBOutlet NSButton *saveDiskImageButton;
@property (strong, nullable) NSSavePanel *diskImageSavePanel;

@property (assign) BOOL defaultToHardDisk;

@end

@implementation DiskMakerWindowController

- (id)init {
    if ((self = [super initWithWindowNibName:@"DiskMakerWindow"]) != nil) {
        self.slot = -1;
        self.drive = -1;
    }
    return self;
}

- (void)selectHardDisk {
    self.defaultToHardDisk = YES;
}

- (void)windowDidLoad {
    if (self.defaultToHardDisk) {
        [self.capacityButton selectItemAtIndex:CAPACITY_32MB];
        [self.formatButton selectItemAtIndex:FORMAT_PRODOS];
    }
    
    [self updateCustomBootSector];
    
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
    
    if (self.slot >= 0 && self.drive >= 0) {
        self.window.subtitle = [NSString stringWithFormat:NSLocalizedString(@"Slot %d Drive %d", @""), self.slot, self.drive + 1];
    }
    
    [self enforceConflicts];
    
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
    [self enforceConflicts];
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
    [self enforceConflicts];
}

- (IBAction)openCustomBootSector:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    self.customBootSectorOpenPanel = [NSOpenPanel openPanel];
    self.customBootSectorOpenPanel.canChooseFiles = YES;
    self.customBootSectorOpenPanel.canChooseDirectories = NO;
    self.customBootSectorOpenPanel.allowsMultipleSelection = NO;
    self.customBootSectorOpenPanel.message = NSLocalizedString(@"Select custom boot sector", @"");
    self.customBootSectorOpenPanel.delegate = self;
    if ([self.customBootSectorOpenPanel runModal] == NSModalResponseOK) {
        NSURL *url = self.customBootSectorOpenPanel.URL;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSString *path = url.filePathURL.path;
        NSDictionary *attrs = [fileManager attributesOfItemAtPath:path error:&error];
        if (error == nil) {
            NSNumber *fileSize = attrs[NSFileSize];
            if (fileSize.integerValue > 0) {
                g_cmdLine.nBootSectorFileSize = fileSize.unsignedIntValue;
                g_cmdLine.sBootSectorFileName = std::string(path.UTF8String);
            }
            [self updateCustomBootSector];
        }
        self.customBootSectorOpenPanel = nil;
    }
}

- (IBAction)clearCustomBootSector:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    g_cmdLine.nBootSectorFileSize = 0;
    g_cmdLine.sBootSectorFileName = "";
    [self updateCustomBootSector];
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
    const BOOL isDisk2     = (capacity == CAPACITY_140KB || capacity == CAPACITY_160KB);
    const BOOL isDOS33     = (format == FORMAT_DOS33 && isDisk2);
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
                          isDisk2 ? NSLocalizedString(@"Blank_Floppy", @"blank floppy disk") :
                                    NSLocalizedString(@"Blank_Hard", @"blank hard disk"),
        [dateFormatter stringFromDate:[NSDate date]],
        extension
    ];
    
    [self.window close];
    
    self.diskImageSavePanel = [NSSavePanel savePanel];
    self.diskImageSavePanel.canCreateDirectories = YES;
    self.diskImageSavePanel.title = NSLocalizedString(@"Save disk image as...", @"");
    self.diskImageSavePanel.nameFieldStringValue = filename;
    if ([self.diskImageSavePanel runModal] == NSModalResponseOK) {
        NSURL *url = self.diskImageSavePanel.URL;
        mariani::MarianiFrame *frame = (mariani::MarianiFrame *)theAppDelegate.emulatorVC.frame;
        if (self.formatButton.indexOfSelectedItem == FORMAT_BLANK) {
            New_Blank_Disk("New Disk Image",
                           [url.filePathURL.path cStringUsingEncoding:NSUTF8StringEncoding],
                           diskSize,
                           isHardDisk,
                           frame);
        }
        else {
            New_DOSProDOS_Disk("New Disk Image",
                               [url.filePathURL.path cStringUsingEncoding:NSUTF8StringEncoding],
                               diskSize,
                               isDOS33,
                               newDiskCopyBitsyBoot,
                               newDiskCopyBitsyBye,
                               newDiskCopyBASIC,
                               newDiskCopyProDOS,
                               frame);
        }
        self.diskImageSavePanel = nil;
        
        if (self.slot >= 0 && self.drive >= 0 && isDisk2) {
            std::string urlFilename(url.fileSystemRepresentation);
            CardManager &cardManager = GetCardMgr();
            Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(self.slot));
            const ImageError_e error = card->InsertDisk(self.drive, urlFilename, IMAGE_USE_FILES_WRITE_PROTECT_STATUS, IMAGE_CREATE);
            if (error == eIMAGE_ERROR_NONE) {
                NSString *status = [NSString stringWithFormat:NSLocalizedString(@"Inserted ‘%@’ into slot %d drive %d", @""),
                                    url.lastPathComponent,
                                    self.slot,
                                    self.drive + 1
                ];
                [theAppDelegate setStatus:status];
                [theAppDelegate updateDriveLights];
            }
            else {
                card->NotifyInvalidImage(self.drive, url.fileSystemRepresentation, error);
            }
        }
    }
}

- (IBAction)cancelAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.window close];
}

- (void)enforceConflicts {
    // The "copy" checkboxes are only for ProDOS formats, and the custom boot sector
    // is only for blank disk images.
    const BOOL isProDOS = (self.formatButton.indexOfSelectedItem == FORMAT_PRODOS);
    const BOOL isBlank = (self.formatButton.indexOfSelectedItem == FORMAT_BLANK);
    self.onFormatCopyProDOSButton.enabled = isProDOS;
    self.onFormatCopyBitsyBootButton.enabled = isProDOS;
    self.onFormatCopyBitsyByeButton.enabled = isProDOS;
    self.onFormatCopyBASICSYSTEMButton.enabled = isProDOS;
    self.customBootSectorButton.enabled = isBlank;
    self.clearCustomBootSectorButton.enabled = isBlank && g_cmdLine.nBootSectorFileSize > 0;
}

- (void)updateCustomBootSector {
    if (g_cmdLine.nBootSectorFileSize > 0) {
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:g_cmdLine.sBootSectorFileName.c_str()]];
        self.customBootSectorButton.title = url.lastPathComponent;
        self.clearCustomBootSectorButton.enabled = YES;
    }
    else {
        self.customBootSectorButton.title = NSLocalizedString(@"Default AppleWin Boot Sector", @"");
        self.clearCustomBootSectorButton.enabled = NO;
    }
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    // never allow navigation into packages
    NSNumber *isPackage;
    if ([url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:nil] &&
        [isPackage boolValue]) {
        return NO;
    }
    
    // always allow navigation into directories
    NSNumber *isDirectory;
    if ([url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil] &&
        [isDirectory boolValue]) {
        return YES;
    }
    
    if ([sender isEqual:self.customBootSectorOpenPanel]) {
        return [url.pathExtension.uppercaseString isEqual:@"BIN"];
    }
    return NO;
}

@end

NS_ASSUME_NONNULL_END
