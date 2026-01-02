//
//  MarianiDriveButton.mm
//  Mariani
//
//  Created by sh95014 on 6/23/25.
//

#import <Cocoa/Cocoa.h>

#import "MarianiDriveButton.h"
#import "AppDelegate.h"
#import "DiskMakerWindowController.h"

// AppleWin
#include <string>
#include <vector>
#import "windows.h"
#import "Card.h"
#import "CardManager.h"
#import "Disk.h"
#import "Harddisk.h"

#import "DiskImg.h"
#import "DiskImageWrapper.h"
using namespace DiskImgLib;

#define BLANK_FILE_NAME     NSLocalizedString(@"Blank", @"default file name for new blank disk")

NS_ASSUME_NONNULL_BEGIN

@interface MarianiDriveButton ()
@property (strong) NSMutableDictionary *browserWindowControllers;
@property (strong, nullable) NSOpenPanel *diskOpenPanel;
@property (strong) DiskImageWrapper *wrapper;
@property (strong) DiskMakerWindowController *diskMakerWC;
@property (strong) NSImageView *imageView;
@end

@implementation MarianiDriveButton

const NSOperatingSystemVersion macOS12 = { 12, 0, 0 };

+ (NSInteger)buttonWidth {
    return 32;
}

+ (instancetype)buttonForFloppyDrive:(int)drive inSlot:(int)slot {
    MarianiDriveButton *button = [[MarianiDriveButton alloc] init];
    button.slot = slot;
    button.drive = drive;
    button.browserWindowControllers = [NSMutableDictionary dictionary];
    [button setButtonType:NSButtonTypeMomentaryPushIn];
    button.bezelStyle = NSBezelStyleShadowlessSquare;
    button.bordered = NO;
    button.title = @"";
    [button setSystemSymbolName:@"circle"];
    button.frame = CGRectMake(0, 0, self.buttonWidth, 29);
    button.target = button;
    button.action = @selector(buttonPressed:);
    
    return button;
}

+ (instancetype)buttonForHardDrive:(int)drive inSlot:(int)slot {
    return [self buttonForFloppyDrive:drive inSlot:slot];
}

+ (instancetype)buttonForTape {
    // not a drive, but easier to share the status bar like this
    MarianiDriveButton *button = [[MarianiDriveButton alloc] init];
    button.slot = -1;
    button.drive = -1;
    [button setButtonType:NSButtonTypeMomentaryPushIn];
    button.bezelStyle = NSBezelStyleShadowlessSquare;
    button.bordered = NO;
    button.enabled = NO;
    button.title = @"";
    [button setSystemSymbolName:@"recordingtape"];
    button.frame = CGRectMake(0, 0, self.buttonWidth, 29);
    
    return button;
}

- (void)updateDriveLight {
    static BOOL isAtLeastMacOS12 = [theAppDelegate.processInfo isOperatingSystemAtLeastVersion:macOS12];
    
    if (self.slot < 0 || self.drive < 0) {
        // cassette tape, do nothing for now
        return;
    }
    
    NSColor *driveSwappingColor = [NSColor controlAccentColor];
    
    CardManager &cardManager = GetCardMgr();
    const int slot = self.slot;
    const int drive = self.drive;
    if (cardManager.QuerySlot(slot) == CT_Disk2) {
        Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard *>(cardManager.GetObj(slot));
        if (card->IsDriveEmpty(drive)) {
            if (isAtLeastMacOS12) {
                [self setSystemSymbolName:@"circle.dotted"];
            }
            else {
                [self setSystemSymbolName:@"circle.dashed"];
            }
            self.imageView.contentTintColor = theAppDelegate.driveSwapCount ? driveSwappingColor : [NSColor secondaryLabelColor];
        }
        else {
            Disk_Status_e status[NUM_DRIVES];
            card->GetLightStatus(&status[0], &status[1]);
            if (status[drive] != DISK_STATUS_OFF) {
                if (card->GetProtect(drive)) {
                    [self setSystemSymbolName:@"lock.circle.fill"];
                }
                else if (@available(macOS 15.0, *)) {
                    [self setSymbolName:@"custom.dot.radiowaves.left.and.right.circle.fill" fallbackSystemSymbolName:@"circle.fill"];
                    [self.imageView addSymbolEffect:[NSSymbolRotateEffect effect]];
                }
                else {
                    [self setSystemSymbolName:@"circle.fill"];
                }
                self.imageView.contentTintColor = theAppDelegate.driveSwapCount ? driveSwappingColor : [NSColor controlAccentColor];
            }
            else {
                if (card->GetProtect(drive)) {
                    [self setSystemSymbolName:@"lock.circle"];
                }
                else {
                    [self setSystemSymbolName:@"circle"];
                }
                self.imageView.contentTintColor = theAppDelegate.driveSwapCount ? driveSwappingColor : [NSColor secondaryLabelColor];
            }
        }
    }
    else if (cardManager.QuerySlot(slot) == CT_GenericHDD) {
        HarddiskInterfaceCard *card = dynamic_cast<HarddiskInterfaceCard *>(cardManager.GetObj(slot));
        Disk_Status_e status;
        card->GetLightStatus(&status);
        if (status != DISK_STATUS_OFF) {
            [self setSystemSymbolName:@"circle.fill"];
            self.imageView.contentTintColor = theAppDelegate.driveSwapCount ? driveSwappingColor : [NSColor controlAccentColor];
        }
        else {
            [self setSystemSymbolName:@"circle"];
            self.imageView.contentTintColor = theAppDelegate.driveSwapCount ? driveSwappingColor : [NSColor secondaryLabelColor];
        }
    }
}

- (void)buttonPressed:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSView *view = (NSView *)sender;
    // menu doesn't have a tag, so we stash the slot/drive in the title
    NSMenu *menu = [[NSMenu alloc] initWithTitle:[NSString stringWithFormat:@"%ld", view.tag]];
    menu.minimumWidth = 200;
    
    // if there's a disk in the drive, show it
    CardManager &cardManager = GetCardMgr();
    const int slot = self.slot;
    const int drive = self.drive;
    if (cardManager.QuerySlot(slot) == CT_Disk2) {
        Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(slot));
        NSString *diskName = [NSString stringWithUTF8String:card->GetFullDiskFilename(drive).c_str()];
        if ([diskName length] > 0) {
            [menu addItemWithTitle:diskName action:nil keyEquivalent:@""];
            
            // see if this disk is browseable
            DiskImg *diskImg = new DiskImg;
            std::string diskPathname = card->DiskGetFullPathName(drive);
            if (diskImg->OpenImage(diskPathname.c_str(), '/', true) == kDIErrNone &&
                diskImg->AnalyzeImage() == kDIErrNone) {
                NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Examine…", @"browse disk image")
                                                                  action:@selector(browseDisk:)
                                                           keyEquivalent:@""];
                menuItem.target = self;
                NSString *pathString = [NSString stringWithUTF8String:diskPathname.c_str()];
                self.wrapper = [[DiskImageWrapper alloc] initWithPath:pathString diskImg:diskImg];
                [menu addItem:menuItem];
            }
            
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Eject", @"eject disk image")
                                                              action:@selector(ejectDisk:)
                                                       keyEquivalent:@""];
            menuItem.target = self;
            [menu addItem:menuItem];
            [menu addItem:[NSMenuItem separatorItem]];
        }
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"New Disk Image…", @"create new disk image")
                                                      action:@selector(createDiskImage:)
                                               keyEquivalent:@""];
        item.target = self;
        [menu addItem:item];
        
        item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Other Disk…", @"open another disk image")
                                          action:@selector(openDiskImage:)
                                   keyEquivalent:@""];
        item.target = self;
        [menu addItem:item];
    }
    else if (cardManager.QuerySlot(slot) == CT_GenericHDD) {
        HarddiskInterfaceCard *card = dynamic_cast<HarddiskInterfaceCard *>(cardManager.GetObj(slot));
        const char *path = card->HarddiskGetFullPathName(drive).c_str();
        NSString *pathString = [NSString stringWithUTF8String:path];
        NSString *diskName = [pathString lastPathComponent];
        if ([diskName length] > 0) {
            [menu addItemWithTitle:diskName action:nil keyEquivalent:@""];
        
            // see if this disk is browseable
            DiskImg *diskImg = new DiskImg;
            if (diskImg->OpenImage(pathString.UTF8String, '/', true) == kDIErrNone &&
                diskImg->AnalyzeImage() == kDIErrNone) {
                NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Examine…", @"browse disk image")
                                                                  action:@selector(browseDisk:)
                                                           keyEquivalent:@""];
                menuItem.target = self;
                self.wrapper = [[DiskImageWrapper alloc] initWithPath:pathString diskImg:diskImg];
                [menu addItem:menuItem];
            }
        }
    }

    [menu popUpMenuPositioningItem:nil atLocation:CGPointZero inView:view];
    if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)view;
        [button setState:NSControlStateValueOff];
    }

}

- (void)browseDisk:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        DiskImageBrowserWindowController *browserWC = [self.browserWindowControllers objectForKey:self.wrapper.path];
        if (browserWC == nil) {
            browserWC = [[DiskImageBrowserWindowController alloc] initWithDiskImageWrapper:self.wrapper];
            if (browserWC != nil) {
                [self.browserWindowControllers setObject:browserWC forKey:self.wrapper.path];
                browserWC.delegate = self;
                [browserWC showWindow:self];
            }
            else {
                [theAppDelegate showModalAlertofType:MB_ICONWARNING | MB_OK
                                         withMessage:NSLocalizedString(@"Unknown Disk Format", @"")
                                         information:NSLocalizedString(@"Unable to interpret the data format stored on this disk.", @"")];
            }
        }
        else {
            [browserWC.window orderFront:self];
        }
    }
}

- (void)ejectDisk:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        const int slot = self.slot;
        const int drive = self.drive;
        CardManager &cardManager = GetCardMgr();
        Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(slot));
        card->EjectDisk(drive);
        [theAppDelegate updateDriveLights];
    }
}

- (void)openDiskImage:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        const int slot = self.slot;
        const int drive = self.drive;
        
        self.diskOpenPanel = [NSOpenPanel openPanel];
        self.diskOpenPanel.canChooseFiles = YES;
        self.diskOpenPanel.canChooseDirectories = NO;
        self.diskOpenPanel.allowsMultipleSelection = NO;
        self.diskOpenPanel.canDownloadUbiquitousContents = YES;
        self.diskOpenPanel.message = [NSString stringWithFormat:NSLocalizedString(@"Select disk image for slot %d drive %d", @"slot, drive"), slot, drive + 1];
        self.diskOpenPanel.prompt = NSLocalizedString(@"Insert", @"..into drive");
        self.diskOpenPanel.delegate = self;
        
        if ([self.diskOpenPanel runModal] == NSModalResponseOK) {
            const char *fileSystemRepresentation = self.diskOpenPanel.URL.fileSystemRepresentation;
            std::string filename(fileSystemRepresentation);
            CardManager &cardManager = GetCardMgr();
            Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(slot));
            const ImageError_e error = card->InsertDisk(drive, filename, IMAGE_USE_FILES_WRITE_PROTECT_STATUS, IMAGE_DONT_CREATE);
            if (error == eIMAGE_ERROR_NONE) {
                NSLog(@"Loaded '%s' into slot %d drive %d",
                      fileSystemRepresentation, slot, drive);
                [theAppDelegate updateDriveLights];
            }
            else {
                NSLog(@"Failed to load '%s' into slot %d drive %d due to error %d",
                      fileSystemRepresentation, slot, drive, error);
                card->NotifyInvalidImage(drive, fileSystemRepresentation, error);
            }
            self.diskOpenPanel = nil;
        }
    }
}

- (void)createDiskImage:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    self.diskMakerWC = [[DiskMakerWindowController alloc] init];
    self.diskMakerWC.slot = self.slot;
    self.diskMakerWC.drive = self.drive;
    [self.diskMakerWC showWindow:self];
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
    
    if ([sender isEqual:self.diskOpenPanel]) {
        return [@[ @"BIN", @"DO", @"DSK", @"NIB", @"PO", @"WOZ", @"ZIP", @"GZIP", @"GZ" ] containsObject:url.pathExtension.uppercaseString];
    }
    return NO;
}

#pragma mark - DiskImageBrowserDelegate

- (void)browserWindowWillClose:(NSString *)path {
    [self.browserWindowControllers removeObjectForKey:path];
}

#pragma mark - SF Symbol subview

+ (NSImageSymbolConfiguration *)symbolConfiguration {
    static NSImageSymbolConfiguration *symbolConfiguration =
        [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleLarge];
    return symbolConfiguration;
}

- (void)setImage:(nullable NSImage *)image {
    NSAssert(NO, @"call setSystemSymbolName or setSymbolName instead");
}

- (void)createImageViewIfNecessary {
    if (self.imageView == nil) {
        self.imageView = [[NSImageView alloc] init];
        self.imageView.frame = self.bounds;
        self.imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:self.imageView];
    }
}

- (void)setSystemSymbolName:(NSString *)symbolName {
    [self createImageViewIfNecessary];
    self.imageView.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@""];
    self.imageView.image = [self.imageView.image imageWithSymbolConfiguration:[[self class] symbolConfiguration]];
}

- (void)setSymbolName:(NSString *)symbolName fallbackSystemSymbolName:(NSString *)fallbackSymbolName {
    [self createImageViewIfNecessary];
    if (@available(macOS 13.0, *)) {
        self.imageView.image = [NSImage imageWithSymbolName:@"custom.dot.radiowaves.left.and.right.circle.fill" variableValue:0];
    }
    else {
        self.imageView.image = [NSImage imageWithSystemSymbolName:fallbackSymbolName accessibilityDescription:@""];
    }
    self.imageView.image = [self.imageView.image imageWithSymbolConfiguration:[[self class] symbolConfiguration]];
}

@end

NS_ASSUME_NONNULL_END
