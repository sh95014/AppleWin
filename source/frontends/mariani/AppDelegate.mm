//
//  AppDelegate.mm
//  Mariani
//
//  Created by sh95014 on 12/27/21.
//

#import "AppDelegate.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/NSProcessInfo.h>
#import <GameController/GameController.h>
#import "windows.h"

#import "context.h"

#import "benchmark.h"
#import "cassettetape.h"
#import "fileregistry.h"
#import "programoptions.h"
#import "sdirectsound.h"
#import "MarianiFrame.h"
#import "utils.h"
#import "version.h"

// AppleWin
#import "Card.h"
#import "CardManager.h"
#import "CPU.h"
#import "Interface.h"
#import "NTSC.h"
#import "Utilities.h"
#import "Video.h"

#import "CommonTypes.h"
#import "EmulatorViewController.h"
#import "PreferencesWindowController.h"
#import "DebuggerWindowController.h"
#import "UserDefaults.h"

#import "DiskImg.h"
#import "DiskImageBrowserWindowController.h"
#import "DiskImageWrapper.h"
using namespace DiskImgLib;

#define STATUS_BAR_HEIGHT   32
#define BLANK_FILE_NAME     NSLocalizedString(@"Blank", @"default file name for new blank disk")

// needs to match tag of Edit menu item in MainMenu.xib
#define EDIT_TAG            3917

// encode the slot-drive tuple into a single number (suitable for use as a
// NSView tag, or decode from it
#define ENCODE_SLOT_DRIVE(s, d) ((char)((s) * 10 + (d)))
#define DECODE_SLOT(t)          ((char)((t) / 10))
#define DECODE_DRIVE(t)         ((char)((t) % 10))

@interface AppDelegate ()

@property (strong) IBOutlet EmulatorViewController *emulatorVC;
@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *createDiskImageMenu;
@property (strong) IBOutlet NSMenu *openDiskImageMenu;
@property (strong) IBOutlet NSMenuItem *editCopyMenu;
@property (strong) IBOutlet NSMenuItem *showHideStatusBarMenuItem;
@property (strong) IBOutlet NSMenu *displayTypeMenu;
@property (strong) IBOutlet NSView *statusBarView;
@property (strong) IBOutlet NSButton *driveLightButtonTemplate;
@property (strong) IBOutlet NSTextField *statusLabel;
@property (strong) IBOutlet NSButton *volumeToggleButton;
@property (strong) IBOutlet NSButton *screenRecordingButton;

@property (strong) IBOutlet NSMenuItem *aboutMarianiMenuItem;

@property (strong) IBOutlet NSWindow *aboutWindow;
@property (strong) IBOutlet NSImageView *aboutImage;
@property (strong) IBOutlet NSTextField *aboutTitle;
@property (strong) IBOutlet NSTextField *aboutVersion;
@property (strong) IBOutlet NSTextField *aboutAppleWinVersion;
@property (strong) IBOutlet NSTextField *aboutCredits;
@property (strong) IBOutlet NSButton *aboutLinkButton;

@property (strong) PreferencesWindowController *preferencesWC;
@property NSArray *driveLightButtons;
@property NSData *driveLightButtonTemplateArchive;
@property BOOL hasStatusBar;
@property (readonly) double statusBarHeight;

@property (strong) NSOpenPanel *diskOpenPanel;
@property (strong) NSOpenPanel *tapeOpenPanel;

@property (strong) NSMutableDictionary *browserWindowControllers;

@property (strong) NSProcessInfo *processInfo;

@property (strong) DebuggerWindowController *debuggerWC;

@end

static void DiskImgMsgHandler(const char *file, int line, const char *msg);

@implementation AppDelegate

Disk_Status_e driveStatus[NUM_SLOTS * NUM_DRIVES];
const NSOperatingSystemVersion macOS12 = { 12, 0, 0 };

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.processInfo = [[NSProcessInfo alloc] init];
    
    Global::SetDebugMsgHandler(DiskImgMsgHandler);
    Global::AppInit();
    
    _hasStatusBar = YES;
    self.driveLightButtonTemplate.hidden = YES;
    self.statusLabel.stringValue = @"";
    self.browserWindowControllers = [NSMutableDictionary dictionary];
    
    NSString *appName = [NSRunningApplication currentApplication].localizedName;
    self.aboutMarianiMenuItem.title = [NSString stringWithFormat:NSLocalizedString(@"About %@", @""), appName];
    
    self.window.delegate = self;
    self.emulatorVC.delegate = self;
    
    // remove the "Start Dictation..." and "Emoji & Symbols" items
    NSMenu *editMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:EDIT_TAG] submenu];
    for (NSMenuItem *item in [editMenu itemArray]) {
        if ([item action] == NSSelectorFromString(@"startDictation:") ||
            [item action] == NSSelectorFromString(@"orderFrontCharacterPalette:")) {
            [editMenu removeItem:item];
        }
    }
    // make sure a separator is not the bottom option
    const NSInteger lastItemIndex = [editMenu numberOfItems] - 1;
    if ([[editMenu itemAtIndex:lastItemIndex] isSeparatorItem]) {
        [editMenu removeItemAtIndex:lastItemIndex];
    }
    
    // populate the Display Type menu with options
    Video &video = GetVideo();
    const VideoType_e currentVideoType = video.GetVideoType();
    for (NSInteger videoType = VT_MONO_CUSTOM; videoType < NUM_VIDEO_MODES; videoType++) {
        NSString *itemTitle = [self localizedVideoType:videoType];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:itemTitle
                                                      action:@selector(displayTypeAction:)
                                               keyEquivalent:@""];
        item.tag = videoType;
        item.state = (currentVideoType == videoType) ? NSControlStateValueOn : NSControlStateValueOff;
        [self.displayTypeMenu addItem:item];
    }
    
    self.driveLightButtonTemplateArchive = [self archiveFromTemplateView:self.driveLightButtonTemplate];
    [self reconfigureDrives];
    
    [self.emulatorVC start];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.emulatorVC stop];

    Global::AppCleanup();
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationDidHide:(NSNotification *)notification {
    [self.emulatorVC pause];
}

- (void)applicationWillUnhide:(NSNotification *)notification {
    [self.emulatorVC start];
}

#pragma mark - NSWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    
    alert.messageText = NSLocalizedString(@"Ending Emulation", @"");
    alert.informativeText = NSLocalizedString(@"This will end the emulation and any unsaved changes will be lost.", @"");
    alert.alertStyle = NSAlertStyleWarning;
    alert.icon = [NSImage imageWithSystemSymbolName:@"hand.raised" accessibilityDescription:@""];
    [alert addButtonWithTitle:NSLocalizedString(@"End Emulation", @"")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
    [alert beginSheetModalForWindow:sender completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self terminateWithReason:@"main window closed"];
        }
    }];
    return NO;
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    // when the main window is key, add a hint that we're copying the
    // screenshot to pasteboard
    self.editCopyMenu.title = NSLocalizedString(@"Copy Screenshot", @"");
}

- (void)windowDidResignKey:(NSNotification *)notification {
    self.editCopyMenu.title = NSLocalizedString(@"Copy", @"");
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
    
    NSArray *supportedTypes = nil;
    if ([sender isEqual:self.diskOpenPanel]) {
        supportedTypes = @[ @"BIN", @"DO", @"DSK", @"NIB", @"PO", @"WOZ", @"ZIP", @"GZIP", @"GZ" ];
    } else if ([sender isEqual:self.tapeOpenPanel]) {
        supportedTypes = @[ @"WAV" ];
    }
    return [supportedTypes containsObject:url.pathExtension.uppercaseString];
}

#pragma mark - EmulatorViewControllerDelegate

- (BOOL)shouldPlayAudio {
    return (self.volumeToggleButton.state == NSControlStateValueOn);
}

- (void)screenRecordingDidStart {
    self.screenRecordingButton.contentTintColor = [NSColor controlAccentColor];
}

- (void)screenRecordingDidTick {
    self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle.fill" accessibilityDescription:@""];
}

- (void)screenRecordingDidTock {
    self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle" accessibilityDescription:@""];
}

- (void)screenRecordingDidStop {
    self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle" accessibilityDescription:@""];
    self.screenRecordingButton.contentTintColor = [NSColor secondaryLabelColor];
}

- (void)updateStatus:(NSString *)status {
    self.statusLabel.stringValue = status;
}

- (NSURL *)unusedURLForFilename:(NSString *)desiredFilename extension:(NSString *)extension inFolder:(NSURL *)folder {
    // walk through the folder to make a set of files that have our prefix
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager]
        enumeratorAtURL:folder
        includingPropertiesForKeys:nil
        options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles)
        errorHandler:^(NSURL *url, NSError *error) { return YES; }];
    NSMutableSet *set = [NSMutableSet set];
    for (NSURL *url in enumerator) {
        NSString *filename = [url lastPathComponent];
        if ([filename hasPrefix:desiredFilename]) {
            [set addObject:filename];
        }
    }
    
    // starting from "1", let's find one that's not already used
    NSString *candidateFilename = [NSString stringWithFormat:@"%@.%@", desiredFilename, extension];
    NSInteger index = 2;
    while ([set containsObject:candidateFilename]) {
        candidateFilename = [NSString stringWithFormat:@"%@ %ld.%@", desiredFilename, index++, extension];
    }
    
    return [folder URLByAppendingPathComponent:candidateFilename];
}

#pragma mark - Mariani menu actions

- (IBAction)aboutAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (self.aboutWindow == nil) {
        if (![[NSBundle mainBundle] loadNibNamed:@"About" owner:self topLevelObjects:nil]) {
            NSLog(@"failed to load About nib");
            return;
        }
        
        if (self.aboutImage.image == nil) {
            self.aboutImage.image = [NSApp applicationIconImage];
            
            self.aboutTitle.stringValue = [NSRunningApplication currentApplication].localizedName;
            
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            self.aboutVersion.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Version %@ (%@)", @""),
                infoDictionary[@"CFBundleShortVersionString"],
                infoDictionary[@"CFBundleVersion"]];
            self.aboutAppleWinVersion.stringValue = [NSString stringWithFormat:NSLocalizedString(@"(Based on AppleWin Version %s)", @""), getVersion().c_str()];
        }
    }
    [self.aboutWindow orderFront:sender];
}

- (IBAction)aboutLinkAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/sh95014/AppleWin"]];
}

#pragma mark - App menu actions

- (IBAction)preferencesAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (self.preferencesWC == nil) {
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Preferences" bundle:nil];
        self.preferencesWC = [storyboard instantiateInitialController];
    }
    [self.preferencesWC showWindow:sender];
}

- (void)terminateWithReason:(NSString *)reason {
    NSLog(@"Terminating due to '%@'", reason);
    [NSApp terminate:self];
}

#pragma mark - File menu actions

- (IBAction)loadTapeAction:(id)sender {
    self.tapeOpenPanel = [NSOpenPanel openPanel];
    self.tapeOpenPanel.canChooseFiles = YES;
    self.tapeOpenPanel.canChooseDirectories = NO;
    self.tapeOpenPanel.allowsMultipleSelection = NO;
    self.tapeOpenPanel.canDownloadUbiquitousContents = YES;
    self.tapeOpenPanel.delegate = self;
    
    if ([self.tapeOpenPanel runModal] == NSModalResponseOK) {
        OSStatus status = noErr;
        
        ExtAudioFileRef inputFile;
        status = ExtAudioFileOpenURL((__bridge CFURLRef)self.tapeOpenPanel.URL, &inputFile);
        
        // set output format to 8-bit 44kHz mono LPCM
        AudioStreamBasicDescription outputFormat;
        outputFormat.mFormatID         = kAudioFormatLinearPCM;
        outputFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger;
        outputFormat.mSampleRate       = 44100;
        outputFormat.mChannelsPerFrame = 1;  // mono
        outputFormat.mBitsPerChannel   = sizeof(CassetteTape::tape_data_t) * CHAR_BIT;
        outputFormat.mFramesPerPacket  = 1;  // uncompressed audio
        outputFormat.mBytesPerFrame    = sizeof(CassetteTape::tape_data_t);
        outputFormat.mBytesPerPacket   = sizeof(CassetteTape::tape_data_t);
        status = ExtAudioFileSetProperty(inputFile,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof(outputFormat),
                                         &outputFormat);
        
        std::vector<CassetteTape::tape_data_t> audioData;
        
        const UInt32 outputBufferSize = 1024 * 1024;
        AudioBufferList convertedData;
        convertedData.mNumberBuffers = 1;
        convertedData.mBuffers[0].mNumberChannels = outputFormat.mChannelsPerFrame;
        convertedData.mBuffers[0].mDataByteSize = outputBufferSize;
        convertedData.mBuffers[0].mData = (UInt8 *)malloc(sizeof(UInt8) * outputBufferSize);
        
        while (true) {
            const UInt8 *data = (UInt8 *)convertedData.mBuffers[0].mData;
            UInt32 frameCount = outputBufferSize / outputFormat.mBytesPerPacket;
            status = ExtAudioFileRead(inputFile,
                                      &frameCount,
                                      &convertedData);
            if (frameCount == 0) {
                free(convertedData.mBuffers[0].mData);
                break;
            }
            audioData.insert(audioData.end(), data, data + frameCount * outputFormat.mBytesPerFrame);
        }
        
        std::string filename(self.tapeOpenPanel.URL.lastPathComponent.UTF8String);
        CassetteTape::instance().setData(filename,
                                         audioData,
                                         outputFormat.mSampleRate);
        
        ExtAudioFileDispose(inputFile);
        self.tapeOpenPanel = nil;
    }
}

- (IBAction)controlResetAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CtrlReset();
}

- (IBAction)rebootEmulatorAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.emulatorVC reboot];
}

#pragma mark - View menu actions

- (IBAction)toggleStatusBarAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    self.hasStatusBar = !self.hasStatusBar;
    self.statusBarView.hidden = !_hasStatusBar;
    [self updateDriveLights];
    
    CGRect emulatorFrame = self.emulatorVC.view.frame;
    CGRect windowFrame = self.window.frame;
    if (self.window.styleMask & NSWindowStyleMaskFullScreen) {
        emulatorFrame = windowFrame;
        if (self.hasStatusBar) {
            emulatorFrame.size.height -= STATUS_BAR_HEIGHT;
            emulatorFrame.origin.y += STATUS_BAR_HEIGHT;
        }
    }
    else {
        // windowed
        const double statusBarHeight = STATUS_BAR_HEIGHT;
        if (self.hasStatusBar) {
            self.showHideStatusBarMenuItem.title = NSLocalizedString(@"Hide Status Bar", @"");
            emulatorFrame.origin.y = statusBarHeight;
            windowFrame.size.height += statusBarHeight;
            windowFrame.origin.y -= statusBarHeight;
        }
        else {
            self.showHideStatusBarMenuItem.title = NSLocalizedString(@"Show Status Bar", @"");
            emulatorFrame.origin.y = 0;
            windowFrame.size.height -= statusBarHeight;
            windowFrame.origin.y += statusBarHeight;
        }
        
        // need to resize the window before the emulator view because the window
        // tries to resize its children when it's being resized.
        [self.window setFrame:windowFrame display:YES animate:NO];
    }
    [self.emulatorVC.view setFrame:emulatorFrame];
}

- (IBAction)displayTypeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        Video &video = GetVideo();
        
        // clear the selected state of the old item
        const VideoType_e currentVideoType = video.GetVideoType();
        NSMenuItem *oldItem = [self.displayTypeMenu itemWithTag:currentVideoType];
        oldItem.state = NSControlStateValueOff;

        // set the new item
        NSMenuItem *newItem = (NSMenuItem *)sender;
        newItem.state = NSControlStateValueOn;
        video.SetVideoType(VideoType_e(newItem.tag));
        [self.emulatorVC videoModeDidChange];
        [self.emulatorVC displayTypeDidChange];
        
        NSLog(@"Set video type to %ld", (long)newItem.tag);
    }
}

- (IBAction)defaultSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    CGRect frame = [self windowRectAtScale:1.5];
    [self.window setFrame:frame display:YES animate:NO];
}

- (IBAction)actualSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    CGRect frame = [self windowRectAtScale:1];
    [self.window setFrame:frame display:YES animate:NO];
}

- (IBAction)doubleSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    CGRect frame = [self windowRectAtScale:2];
    [self.window setFrame:frame display:YES animate:NO];
}

- (IBAction)increaseSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    [self scaleWindowByFactor:1.2];
}

- (IBAction)decreaseSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    [self scaleWindowByFactor:0.8];
}

#pragma mark - Window menu actions

- (IBAction)showDebuggerAction:(id)sender {
    [self.emulatorVC enterDebugMode];
    
    if (self.debuggerWC == nil) {
        self.debuggerWC = [[DebuggerWindowController alloc] initWithEmulatorVC:self.emulatorVC];
    }
    [self.debuggerWC.window orderFront:sender];
}

#pragma mark - Main window actions

- (IBAction)driveLightAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSView *view = (NSView *)sender;
    const int slot = DECODE_SLOT(view.tag);
    const int drive = DECODE_DRIVE(view.tag);
    // menu doesn't have a tag, so we stash the slot/drive in the title
    NSMenu *menu = [[NSMenu alloc] initWithTitle:[NSString stringWithFormat:@"%ld", view.tag]];
    menu.minimumWidth = 200;
    
    // if there's a disk in the drive, show it
    CardManager &cardManager = GetCardMgr();
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
                NSString *pathString = [NSString stringWithUTF8String:diskPathname.c_str()];
                menuItem.representedObject = [[DiskImageWrapper alloc] initWithPath:pathString diskImg:diskImg];
                [menu addItem:menuItem];
            }
            
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Eject", @"eject disk image")
                                                              action:@selector(ejectDisk:)
                                                       keyEquivalent:@""];
            menuItem.representedObject = @[ @(slot), @(drive) ];
            [menu addItem:menuItem];
            [menu addItem:[NSMenuItem separatorItem]];
        }
        
        NSMenuItem *item;
         
        item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Other Disk…", @"open another disk image")
                                          action:@selector(openDiskImage:)
                                   keyEquivalent:@""];
        item.representedObject = @[ @(slot), @(drive) ];
        [menu addItem:item];
    }
    else if (cardManager.QuerySlot(slot) == CT_GenericHDD) {
        HarddiskInterfaceCard *card = dynamic_cast<HarddiskInterfaceCard *>(cardManager.GetObj(slot));
        const char *path = card->HarddiskGetFullPathName(0).c_str();
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
                menuItem.representedObject = [[DiskImageWrapper alloc] initWithPath:pathString diskImg:diskImg];
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
        NSMenuItem *menuItem = (NSMenuItem *)sender;
        if ([menuItem.representedObject isKindOfClass:[DiskImageWrapper class]]) {
            DiskImageWrapper *wrapper = (DiskImageWrapper *)menuItem.representedObject;
            DiskImageBrowserWindowController *browserWC = [self.browserWindowControllers objectForKey:wrapper.path];
            if (browserWC == nil) {
                browserWC = [[DiskImageBrowserWindowController alloc] initWithDiskImageWrapper:wrapper];
                if (browserWC != nil) {
                    [self.browserWindowControllers setObject:browserWC forKey:wrapper.path];
                    [browserWC showWindow:self];
                }
                else {
                    [self showModalAlertofType:MB_ICONWARNING | MB_OK
                                   withMessage:NSLocalizedString(@"Unknown Disk Format", @"")
                                   information:NSLocalizedString(@"Unable to interpret the data format stored on this disk.", @"")];
                }
            }
            else {
                [browserWC.window orderFront:self];
            }
        }
    }
}

- (void)ejectDisk:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = (NSMenuItem *)sender;
        const int slot = [menuItem.representedObject[0] intValue];
        const int drive = [menuItem.representedObject[1] intValue];
        
        CardManager &cardManager = GetCardMgr();
        Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(slot));
        card->EjectDisk(drive);
        [self updateDriveLights];
    }
}

- (void)openDiskImage:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = (NSMenuItem *)sender;
        const int slot = [menuItem.representedObject[0] intValue];
        const int drive = [menuItem.representedObject[1] intValue];
        
        self.diskOpenPanel = [NSOpenPanel openPanel];
        self.diskOpenPanel.canChooseFiles = YES;
        self.diskOpenPanel.canChooseDirectories = NO;
        self.diskOpenPanel.allowsMultipleSelection = NO;
        self.diskOpenPanel.canDownloadUbiquitousContents = YES;
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
                [self updateDriveLights];
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

- (void)createBlankDiskImage:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = (NSMenuItem *)sender;
        const int slot = [menuItem.representedObject[0] intValue];
        const int drive = [menuItem.representedObject[1] intValue];

        NSString *lastPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSNavLastRootDirectory"];
        lastPath = [lastPath stringByStandardizingPath];
        NSURL *folder = [NSURL fileURLWithPath:lastPath];
        if (folder == nil) {
            // fall back to ~/Desktop
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
            folder = [NSURL fileURLWithPath:[paths objectAtIndex:0]];
        }

        NSURL *url = [self unusedURLForFilename:BLANK_FILE_NAME extension:@"dsk" inFolder:folder];
        std::string filename(url.fileSystemRepresentation);
        CardManager &cardManager = GetCardMgr();
        Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(slot));
        const ImageError_e error = card->InsertDisk(drive, filename, IMAGE_USE_FILES_WRITE_PROTECT_STATUS, IMAGE_CREATE);
        if (error == eIMAGE_ERROR_NONE) {
            NSLog(@"Loaded '%s' into slot %d drive %d",
                  url.fileSystemRepresentation, slot, drive);
            [self updateDriveLights];
        }
        else {
            NSLog(@"Failed to load '%s' into slot %d drive %d due to error %d",
                  url.fileSystemRepresentation, slot, drive, error);
            card->NotifyInvalidImage(drive, url.fileSystemRepresentation, error);
        }
    }
}

- (IBAction)recordScreenAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.emulatorVC toggleScreenRecording];
}

- (IBAction)saveScreenshotAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    [self.emulatorVC saveScreenshot];
}

#pragma mark - Helpers because I can't figure out how to make 'frame' properly global

- (void)applyVideoModeChange {
    [self.emulatorVC videoModeDidChange];
}

- (void)browserWindowWillClose:(NSString *)path {
    [self.browserWindowControllers removeObjectForKey:path];
}

- (BOOL)emulationHardwareChanged {
    return [self.emulatorVC emulationHardwareChanged];
}

- (void)reconfigureDrives {
    NSInteger driveLightsRightEdge = self.driveLightButtonTemplate.frame.origin.x;
    
    // only using as template, never actually show this button
    self.driveLightButtonTemplate.hidden = YES;
    
    const NSInteger oldDriveLightButtonsCount = self.driveLightButtons.count;
    
    // remove the old light buttons, if any
    for (NSView *button in self.driveLightButtons) {
        [button removeFromSuperview];
    }
    [self.createDiskImageMenu removeAllItems];
    [self.openDiskImageMenu removeAllItems];
    
    NSMutableArray *driveLightButtons = [NSMutableArray array];
    NSInteger position = 0;
    CardManager &cardManager = GetCardMgr();
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        if (cardManager.QuerySlot(slot) == CT_Disk2) {
            for (int drive = DRIVE_1; drive < NUM_DRIVES; drive++) {
                NSButton *driveLightButton = (NSButton *)[self viewCopyFromArchive:self.driveLightButtonTemplateArchive];

                [driveLightButtons addObject:driveLightButton];
                [[self.driveLightButtonTemplate superview] addSubview:driveLightButton];
                
                // offset each drive light button from the left
                CGRect driveLightButtonFrame = driveLightButton.frame;
                driveLightButtonFrame.origin.x = self.driveLightButtonTemplate.frame.origin.x + position * self.driveLightButtonTemplate.frame.size.width;
                driveLightButton.frame = driveLightButtonFrame;
                driveLightsRightEdge = CGRectGetMaxX(driveLightButtonFrame);
                
                driveLightButton.tag = ENCODE_SLOT_DRIVE(slot, drive);
                driveLightButton.hidden = NO;

                NSString *driveName = [NSString stringWithFormat:NSLocalizedString(@"Slot %d Drive %d", @""), slot, drive + 1];
                NSMenuItem *item;
                item = [[NSMenuItem alloc] initWithTitle:driveName
                                                  action:@selector(createBlankDiskImage:)
                                           keyEquivalent:@""];
                item.representedObject = @[ @(slot), @(drive) ];
                [self.createDiskImageMenu addItem:item];
                
                item = [[NSMenuItem alloc] initWithTitle:driveName
                                                  action:@selector(openDiskImage:)
                                           keyEquivalent:@""];
                item.representedObject = @[ @(slot), @(drive) ];
                [self.openDiskImageMenu addItem:item];
                driveLightButton.toolTip = driveName;

                position++;
            }
        }
    }
    
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        if (cardManager.QuerySlot(slot) == CT_GenericHDD) {
            NSButton *driveLightButton = (NSButton *)[self viewCopyFromArchive:self.driveLightButtonTemplateArchive];
            
            [driveLightButtons addObject:driveLightButton];
            [[self.driveLightButtonTemplate superview] addSubview:driveLightButton];
            
            // offset each drive light button from the left
            CGRect driveLightButtonFrame = driveLightButton.frame;
            driveLightButtonFrame.origin.x = self.driveLightButtonTemplate.frame.origin.x + position * self.driveLightButtonTemplate.frame.size.width;
            driveLightButton.frame = driveLightButtonFrame;
            driveLightsRightEdge = CGRectGetMaxX(driveLightButtonFrame);
            
            driveLightButton.tag = ENCODE_SLOT_DRIVE(slot, 0);
            driveLightButton.hidden = NO;
            
            NSString *driveName = [NSString stringWithFormat:NSLocalizedString(@"Slot %d Hard Disk", @""), slot];
            driveLightButton.toolTip = driveName;
            
            position++;

        }
    }
    
    self.driveLightButtons = driveLightButtons;
    
    CGRect statusLabelFrame = self.statusLabel.frame;
    statusLabelFrame.origin.x = driveLightsRightEdge + 5;
    statusLabelFrame.size.width = self.volumeToggleButton.frame.origin.x - statusLabelFrame.origin.x - 5;
    self.statusLabel.frame = statusLabelFrame;
    
    if (self.driveLightButtons.count != oldDriveLightButtonsCount) {
        // constrain our window to not allow it to be resized so small that our
        // status bar buttons overlap
        [self.window setContentMinSize:[self minimumContentSizeAtScale:1]];
    }
    
    [self updateDriveLights];
}

- (void)reinitializeFrame {
    [self.emulatorVC reinitialize];
}

- (int)showModalAlertofType:(int)type
                withMessage:(NSString *)message
                information:(NSString *)information
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    alert.messageText = message;
    alert.informativeText = information;

    // the #defines unfortunately don't have bitmasks defined, but we'll
    // assume that's the intention.
    
    switch (type & 0x000000F0) {
        case MB_ICONINFORMATION:  // also MB_ICONASTERISK
            alert.alertStyle = NSAlertStyleInformational;
            alert.icon = [NSImage imageWithSystemSymbolName:@"info.circle" accessibilityDescription:@""];
            break;
        case MB_ICONSTOP:  // also MB_ICONHAND
            alert.alertStyle = NSAlertStyleCritical;
            // NSAlertStyleCritical comes with its own image already
            break;
        case MB_ICONQUESTION:
            alert.alertStyle = NSAlertStyleWarning;
            alert.icon = [NSImage imageWithSystemSymbolName:@"questionmark.circle" accessibilityDescription:@""];
            break;
        default:  // MB_ICONWARNING
            alert.alertStyle = NSAlertStyleWarning;
            alert.icon = [NSImage imageWithSystemSymbolName:@"exclamationmark.triangle" accessibilityDescription:@""];
            break;
    }
    
    switch (type & 0x0000000F) {
        case MB_YESNO:
            [alert addButtonWithTitle:NSLocalizedString(@"Yes", @"")];
            [alert addButtonWithTitle:NSLocalizedString(@"No", @"")];
            break;
        case MB_YESNOCANCEL:
            [alert addButtonWithTitle:NSLocalizedString(@"Yes", @"")];
            [alert addButtonWithTitle:NSLocalizedString(@"No", @"")];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
            break;
        case MB_OKCANCEL:
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
            break;
        case MB_OK:
        default:
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
            break;
    }
    
    NSModalResponse returnCode = [alert runModal];
    
    switch (type & 0x0000000F) {
        case MB_YESNO:
            return (returnCode == NSAlertFirstButtonReturn) ? IDYES : IDNO;
        case MB_YESNOCANCEL:
            if (returnCode == NSAlertFirstButtonReturn) {
                return IDYES;
            }
            else if (returnCode == NSAlertSecondButtonReturn) {
                return IDNO;
            }
            else {
                return IDCANCEL;
            }
        case MB_OK:
            return IDOK;
        case MB_OKCANCEL:
            return (returnCode == NSAlertFirstButtonReturn) ? IDOK : IDCANCEL;
    }
    return IDOK;
}

- (void)updateDriveLights {
    if (self.hasStatusBar) {
        for (NSButton *driveLightButton in self.driveLightButtons) {
            CardManager &cardManager = GetCardMgr();
            const UINT slot = DECODE_SLOT(driveLightButton.tag);
            const int drive = DECODE_DRIVE(driveLightButton.tag);
            if (cardManager.QuerySlot(slot) == CT_Disk2) {
                Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard *>(cardManager.GetObj(slot));
                if (card->IsDriveEmpty(drive)) {
                    if ([self.processInfo isOperatingSystemAtLeastVersion:macOS12]) {
                        driveLightButton.image = [NSImage imageWithSystemSymbolName:@"circle.dotted" accessibilityDescription:@""];
                    }
                    else {
                        driveLightButton.image = [NSImage imageWithSystemSymbolName:@"circle.dashed" accessibilityDescription:@""];
                    }
                    driveLightButton.contentTintColor = [NSColor secondaryLabelColor];
                }
                else {
                    Disk_Status_e status[NUM_DRIVES];
                    card->GetLightStatus(&status[0], &status[1]);
                    if (status[drive] != DISK_STATUS_OFF) {
                        if (card->GetProtect(drive)) {
                            driveLightButton.image = [NSImage imageWithSystemSymbolName:@"lock.circle.fill" accessibilityDescription:@""];
                        }
                        else {
                            driveLightButton.image = [NSImage imageWithSystemSymbolName:@"circle.fill" accessibilityDescription:@""];
                        }
                        driveLightButton.contentTintColor = [NSColor controlAccentColor];
                    }
                    else {
                        if (card->GetProtect(drive)) {
                            driveLightButton.image = [NSImage imageWithSystemSymbolName:@"lock.circle" accessibilityDescription:@""];
                        }
                        else {
                            driveLightButton.image = [NSImage imageWithSystemSymbolName:@"circle" accessibilityDescription:@""];
                        }
                        driveLightButton.contentTintColor = [NSColor secondaryLabelColor];
                    }
                }
            }
            else if (cardManager.QuerySlot(slot) == CT_GenericHDD) {
                HarddiskInterfaceCard *card = dynamic_cast<HarddiskInterfaceCard *>(cardManager.GetObj(slot));
                Disk_Status_e status;
                card->GetLightStatus(&status);
                if (status != DISK_STATUS_OFF) {
                    driveLightButton.image = [NSImage imageWithSystemSymbolName:@"circle.fill" accessibilityDescription:@""];
                    driveLightButton.contentTintColor = [NSColor controlAccentColor];
                }
                else {
                    driveLightButton.image = [NSImage imageWithSystemSymbolName:@"circle" accessibilityDescription:@""];
                    driveLightButton.contentTintColor = [NSColor secondaryLabelColor];
                }
            }
        }
    }
}

#pragma mark - Utilities

- (NSString *)localizedVideoType:(NSInteger)videoType {
    static NSDictionary *videoTypeNames;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        videoTypeNames = @{
            @(VT_MONO_CUSTOM): NSLocalizedString(@"Monochrome (Custom)", @""),
            @(VT_COLOR_IDEALIZED): NSLocalizedString(@"Color (Composite Idealized)", @"Color rendering from AppleWin 1.25 (GH#357)"),
            @(VT_COLOR_VIDEOCARD_RGB): NSLocalizedString(@"Color (RGB Card/Monitor)", @"Real RGB card rendering"),
            @(VT_COLOR_MONITOR_NTSC): NSLocalizedString(@"Color (Composite Monitor)", @"NTSC or PAL"),
            @(VT_COLOR_TV): NSLocalizedString(@"Color TV", @""),
            @(VT_MONO_TV): NSLocalizedString(@"B&W TV", @""),
            @(VT_MONO_AMBER): NSLocalizedString(@"Monochrome (Amber)", @""),
            @(VT_MONO_GREEN): NSLocalizedString(@"Monochrome (Green)", @""),
            @(VT_MONO_WHITE): NSLocalizedString(@"Monochrome (White)", @""),
        };
    });
    
    NSString *name = [videoTypeNames objectForKey:[NSNumber numberWithInt:(int)videoType]];
    return (name != nil) ? name : NSLocalizedString(@"Unknown", @"");
}

- (NSView *)viewCopyFromTemplateView:(NSView *)templateView {
    return [self viewCopyFromArchive:[self archiveFromTemplateView:templateView]];
}

- (NSData *)archiveFromTemplateView:(NSView *)templateView {
    NSError *error;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:templateView requiringSecureCoding:NO error:&error];
    if (error != nil) {
        NSLog(@"%s: %@", __PRETTY_FUNCTION__, error.localizedDescription);
        return nil;
    }
    return archive;
}

- (NSView *)viewCopyFromArchive:(NSData *)templateArchive {
    NSError *error;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:templateArchive error:&error];
    unarchiver.requiresSecureCoding = NO;
    NSView *view = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    if (error != nil) {
        NSLog(@"%s: %@", __PRETTY_FUNCTION__, error.localizedDescription);
    }
    return view;
}

- (CGSize)minimumContentSizeAtScale:(double)scale {
    NSSize minimumSize;
    // width of all the things in the status bar...
    minimumSize.width =
        self.driveLightButtonTemplate.frame.origin.x +                                      // left margin
        self.driveLightButtonTemplate.frame.size.width * self.driveLightButtons.count +     // drive light buttons
        40 +                                                                                // a healthy margin
        (self.window.frame.size.width - self.volumeToggleButton.frame.origin.x);            // buttons on the right
    // ...but no less than 2 pt per Apple ][ pixel
    Video &video = GetVideo();
    if (minimumSize.width < video.GetFrameBufferBorderlessWidth() * scale) {
        minimumSize.width = video.GetFrameBufferBorderlessWidth() * scale;
    }
    minimumSize.height = video.GetFrameBufferBorderlessHeight() * scale + self.statusBarHeight;  // status bar height
    return minimumSize;
}

- (CGRect)windowRectAtScale:(double)scale {
    CGRect windowFrame = self.window.frame;
    CGRect contentFrame = self.window.contentLayoutRect;

    CGRect frame;
    frame.size = [self minimumContentSizeAtScale:scale];
    frame.size.height += windowFrame.size.height - contentFrame.size.height;  // window chrome?

    // center the new window at the center of the old one
    frame.origin.x = windowFrame.origin.x + (windowFrame.size.width - frame.size.width) / 2;
    frame.origin.y = windowFrame.origin.y + (windowFrame.size.height - frame.size.height) / 2;
    
    return frame;
}

- (void)scaleWindowByFactor:(double)factor {
    CGRect windowFrame = self.window.frame;
    CGRect contentFrame = self.window.contentLayoutRect;
    
    CGRect frame;
    frame.size.width = contentFrame.size.width * factor;
    // keep status bar out of the scaling because it's fixed height
    frame.size.height = (contentFrame.size.height - [self statusBarHeight]) * factor;
    frame.size.height += [self statusBarHeight];

    // but no smaller than minimum
    CGSize minimumSize = [self minimumContentSizeAtScale:1];
    if (frame.size.width < minimumSize.width || frame.size.height < minimumSize.height) {
        frame.size = minimumSize;
    }
    
    frame.size.height += windowFrame.size.height - contentFrame.size.height;  // window chrome?
    
    // center the new window at the center of the old one
    frame.origin.x = windowFrame.origin.x + (windowFrame.size.width - frame.size.width) / 2;
    frame.origin.y = windowFrame.origin.y + (windowFrame.size.height - frame.size.height) / 2;
    
    [self.window setFrame:frame display:YES animate:NO];
}

- (double)statusBarHeight {
    return self.hasStatusBar ? STATUS_BAR_HEIGHT : 0;
}

@end

#pragma mark - C++ Helpers

// These are needed because AppleWin redeclares BOOL in wincompat.h, so
// MarianiFrame can't be compile as Objective-C++ to call these methods
// itself.

int ShowModalAlertOfType(int type, const char *message, const char *information) {
    return [theAppDelegate showModalAlertofType:type
                                    withMessage:[NSString stringWithUTF8String:message]
                                    information:[NSString stringWithUTF8String:information]];
}

void UpdateDriveLights() {
    [theAppDelegate updateDriveLights];
}

const char *PathToResourceNamed(const char *name) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:[NSString stringWithUTF8String:name] ofType:nil];
    return (path != nil) ? path.UTF8String : NULL;
}

const char *GetSupportDirectory() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSString *supportDirectoryPath = [NSString stringWithFormat:@"%@/%@/", paths.firstObject, bundleId];
    NSURL *url = [NSURL fileURLWithPath:supportDirectoryPath isDirectory:YES];

    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
    if (error != nil) {
        NSLog(@"Failed to create support directory: %@", error.localizedDescription);
        [theAppDelegate terminateWithReason:@"no app support directory"];
    }
    
    return supportDirectoryPath.UTF8String;
}

const char *GetBuiltinSymbolsDirectory() {
    NSString *path = [[NSBundle mainBundle] pathForResource:nil ofType:@"SYM"];
    NSInteger filenameLength = path.lastPathComponent.length;
    return [path substringToIndex:path.length - filenameLength].UTF8String;
}

int RegisterAudioOutput(size_t channels, size_t sampleRate) {
    return [theAppDelegate.emulatorVC registerAudioOutputWithChannels:(UInt32)channels sampleRate:(UInt32)sampleRate];
}

void SubmitAudio(int output, void *p1, size_t len1, void *p2, size_t len2) {
    if (theAppDelegate.emulatorVC.isRecordingScreen) {
        NSMutableData *data = [NSMutableData dataWithBytes:p1 length:len1];
        if (len2 > 0) {
            [data appendBytes:p2 length:len2];
        }
        [theAppDelegate.emulatorVC submitOutput:output audioData:data];
    }
}

static void
DiskImgMsgHandler(const char *file, int line, const char *msg)
{
    assert(file != nil);
    assert(msg != nil);

#ifdef DEBUG
    fprintf(stderr, "%s:%d: %s\n", file, line, msg);
#endif
}
