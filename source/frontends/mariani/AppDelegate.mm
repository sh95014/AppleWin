//
//  AppDelegate.mm
//  Mariani
//
//  Created by sh95014 on 12/27/21.
//

#import "AppDelegate.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Carbon/Carbon.h>
#import "windows.h"

#import "context.h"

#import "benchmark.h"
#import "cassettetape.h"
#import "fileregistry.h"
#import "programoptions.h"
#import "sdirectsound.h"
#import "MarianiFrame.h"
#import "version.h"

// AppleWin
#import "Card.h"
#import "CardManager.h"
#import "Interface.h"
#import "NTSC.h"
#import "Pravets.h"
#import "Utilities.h"
#import "Video.h"

#import "CommonTypes.h"
#import "DiskMakerWindowController.h"
#import "EmulatorViewController.h"
#import "PreferencesWindowController.h"
#import "MarianiDriveButton.h"
#import "MemoryViewerWindowController.h"
#import "DebuggerWindowController.h"
#import "UserDefaults.h"

#import "DiskImg.h"
using namespace DiskImgLib;

#define STATUS_BAR_HEIGHT           32
#define STATUS_BAR_LEFT_MARGIN      5
#define STATUS_BAR_BOTTOM_MARGIN    2

// needs to match tag of Edit menu item in MainMenu.xib
#define EDIT_TAG            3917

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *openDiskImageMenu;
@property (strong) IBOutlet NSMenuItem *editCopyMenu;
@property (strong) IBOutlet NSMenuItem *showHideStatusBarMenuItem;
@property (strong) IBOutlet NSMenu *displayTypeMenu;
@property (strong) IBOutlet NSView *statusBarView;
@property (strong) IBOutlet NSTextField *statusLabel;
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
@property NSArray *driveButtons;
@property BOOL hasStatusBar;
@property (readonly) double statusBarHeight;

@property (strong) NSOpenPanel *tapeOpenPanel;
@property (strong) NSOpenPanel *stateOpenPanel;
@property (strong) NSSavePanel *stateSavePanel;

@property (strong) MemoryViewerWindowController *memoryWC;
@property (strong) DebuggerWindowController *debuggerWC;
@property (strong) DiskMakerWindowController *diskMakerWC;

@end

static void DiskImgMsgHandler(const char *file, int line, const char *msg);

@implementation AppDelegate

Disk_Status_e driveStatus[NUM_SLOTS * NUM_DRIVES];

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.processInfo = [[NSProcessInfo alloc] init];
    
    Global::SetDebugMsgHandler(DiskImgMsgHandler);
    Global::AppInit();
    
    _hasStatusBar = YES;
    [self setStatus:nil];
    
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
    
    [self reconfigureDrives];
    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        const BOOL shift = (event.modifierFlags & NSEventModifierFlagShift) != 0;
        const BOOL control = (event.modifierFlags & NSEventModifierFlagControl) != 0;
        const BOOL option = (event.modifierFlags & NSEventModifierFlagOption) != 0;
        const BOOL command = (event.modifierFlags & NSEventModifierFlagCommand) != 0;
        Video &video = GetVideo();
        switch (event.keyCode) {
            case kVK_F2: {
                NSAlert *alert = [[NSAlert alloc] init];
                
                alert.messageText = NSLocalizedString(@"Reboot?", @"");
                alert.informativeText = NSLocalizedString(@"This will restart the emulation and any unsaved changes will be lost.", @"");
                alert.alertStyle = NSAlertStyleWarning;
                alert.icon = [NSImage imageWithSystemSymbolName:@"hand.raised" accessibilityDescription:@""];
                [alert addButtonWithTitle:NSLocalizedString(@"Reboot", @"")];
                [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSAlertFirstButtonReturn) {
                        [self rebootEmulatorAction:self];
                    }
                }];
                break;
            }
            case kVK_F5: {
                self.driveSwapCount++;
                dynamic_cast<Disk2InterfaceCard&>(GetCardMgr().GetRef(SLOT6)).DriveSwap();
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.driveSwapCount--;
                    [self updateDriveLights];
                });
                break;
            }
            case kVK_F9:
                if (shift && control && !option && !command) {
                    // ^⇧F9: toggle 50% scan lines
                    video.SetVideoStyle(VideoStyle_e(video.GetVideoStyle() ^ VS_HALF_SCANLINES));
                    [self applyVideoModeChange];
                    return nil;
                }
                else if (!shift && !control && !option && !command) {
                    // F9: cycle through display types
                    NSMenuItem *newItem = [self.displayTypeMenu itemWithTag:(video.GetVideoType() + 1) % NUM_VIDEO_MODES];
                    [self displayTypeAction:newItem];
                    return nil;
                }
            case kVK_F10:
                switch (g_Apple2Type) {
                    case A2TYPE_APPLE2E:
                    case A2TYPE_APPLE2EENHANCED:
                    case A2TYPE_BASE64A:
                        // toggle rocker switch
                        video.SetVideoRomRockerSwitch(!video.GetVideoRomRockerSwitch());
                        NTSC_VideoInitAppleType();
                        break;
                    case A2TYPE_PRAVETS8A:
                        GetPravets().ToggleP8ACapsLock();
                        break;
                    default:
                        break;
                }
        }
        return event;
    }];
    
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    [[NSNotificationCenter defaultCenter] addObserverForName:EmulatorDidChangeDisplayNotification object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
        CGRect frame = [self windowRectAtScale:self.windowRectScale];
        [self.window setFrame:frame display:YES animate:NO];
    }];
    
    [self.emulatorVC start];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    
    if ([sender isEqual:self.tapeOpenPanel]) {
        return [url.pathExtension.uppercaseString isEqual:@"WAV"];
    }
    else if ([sender isEqual:self.stateOpenPanel]) {
        NSArray <NSString *> *components = [url.filePathURL.lastPathComponent componentsSeparatedByString:@"."];
        NSInteger count = components.count;
        return count > 2 &&
            [components[count - 2].uppercaseString isEqual:@"AWS"] &&
            [components[count - 1].uppercaseString isEqual:@"YAML"];
    }
    return NO;
}

#pragma mark - EmulatorViewControllerDelegate

- (void)screenRecordingDidStart {
    self.screenRecordingButton.contentTintColor = [NSColor controlAccentColor];
}

- (void)screenRecordingDidTick {
    self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle.fill" accessibilityDescription:@""];
}

- (void)screenRecordingDidTock {
    self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle" accessibilityDescription:@""];
}

- (void)screenRecordingDidStop:(NSURL *)url {
    self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle" accessibilityDescription:@""];
    self.screenRecordingButton.contentTintColor = [NSColor secondaryLabelColor];
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Recording saved to ‘%s’", @""), url.fileSystemRepresentation]];
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

- (IBAction)createDiskImageAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.diskMakerWC = [[DiskMakerWindowController alloc] init];
    [self.diskMakerWC showWindow:self];
}

- (IBAction)loadTapeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.tapeOpenPanel = [NSOpenPanel openPanel];
    self.tapeOpenPanel.canChooseFiles = YES;
    self.tapeOpenPanel.canChooseDirectories = NO;
    self.tapeOpenPanel.allowsMultipleSelection = NO;
    self.tapeOpenPanel.canDownloadUbiquitousContents = YES;
    self.tapeOpenPanel.message = NSLocalizedString(@"Select tape image", @"");
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

- (IBAction)loadStateAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.stateOpenPanel = [NSOpenPanel openPanel];
    self.stateOpenPanel.canChooseFiles = YES;
    self.stateOpenPanel.canChooseDirectories = NO;
    self.stateOpenPanel.allowsMultipleSelection = NO;
    self.stateOpenPanel.canDownloadUbiquitousContents = YES;
    self.stateOpenPanel.message = NSLocalizedString(@"Select save state file", @"");
    NSURL *snapshotURL = [NSURL fileURLWithPath:[self.emulatorVC snapshotPath]];
    self.stateOpenPanel.directoryURL = [snapshotURL URLByDeletingLastPathComponent];
    self.stateOpenPanel.delegate = self;
    
    if ([self.stateOpenPanel runModal] == NSModalResponseOK) {
        NSString *path = [self.emulatorVC loadSnapshot:self.stateOpenPanel.URL];
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"State loaded from ‘%@’", @""), path]];
        self.stateOpenPanel = nil;
    }
}

- (IBAction)saveStateAsAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.stateSavePanel = [NSSavePanel savePanel];
    self.stateSavePanel.canCreateDirectories = YES;
    self.stateSavePanel.title = NSLocalizedString(@"Save state as...", @"");
    NSURL *snapshotURL = [NSURL fileURLWithPath:[self.emulatorVC snapshotPath]];
    self.stateSavePanel.nameFieldStringValue = snapshotURL.lastPathComponent;
    self.stateSavePanel.directoryURL = [snapshotURL URLByDeletingLastPathComponent];
    self.stateSavePanel.delegate = self;
    
    if ([self.stateSavePanel runModal] == NSModalResponseOK) {
        NSURL *url = self.stateSavePanel.URL.filePathURL;
        NSString *lastPathComponent = url.lastPathComponent;
        if (![lastPathComponent hasSuffix:@".aws.yaml"]) {
            if ([lastPathComponent hasSuffix:@".aws"]) {
                url = [url URLByAppendingPathExtension:@"yaml"];
            }
            else {
                url = [url URLByAppendingPathExtension:@"aws.yaml"];
            }
        }
        NSString *path = [self.emulatorVC saveSnapshot:url];
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"State saved to ‘%@’", @""), path]];
        self.stateSavePanel = nil;
    }
}

- (IBAction)saveStateAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSString *path = [self.emulatorVC saveSnapshot:nil];
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"State saved to ‘%@’", @""), path]];
}

- (IBAction)controlResetAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CtrlReset();
}

- (IBAction)rebootEmulatorAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self setStatus:nil];
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

- (IBAction)showMemoryViewerAction:(id)sender {
    if (self.memoryWC == nil) {
        self.memoryWC = [[MemoryViewerWindowController alloc] init];
    }
    [self.memoryWC.window orderFront:sender];
}

- (IBAction)showDebuggerAction:(id)sender {
    [self.emulatorVC enterDebugMode];
    
    if (self.debuggerWC == nil) {
        self.debuggerWC = [[DebuggerWindowController alloc] initWithEmulatorVC:self.emulatorVC];
    }
    [self.debuggerWC.window orderFront:sender];
}

#pragma mark - Main window actions

- (IBAction)recordScreenAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.emulatorVC toggleScreenRecording];
}

- (IBAction)saveScreenshotAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSURL *url = [self.emulatorVC saveScreenshot:NO];
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Screenshot saved to ‘%s’", @""), url.fileSystemRepresentation]];
}

#pragma mark - Helpers because I can't figure out how to make 'frame' properly global

- (void)applyVideoModeChange {
    [self.emulatorVC videoModeDidChange];
}

- (BOOL)emulationHardwareChanged {
    return [self.emulatorVC emulationHardwareChanged];
}

- (void)reconfigureDrives {
    const NSInteger oldDriveLightButtonsCount = self.driveButtons.count;
    
    // clean up old drives
    for (NSView *button in self.driveButtons) {
        [button removeFromSuperview];
    }
    [self.openDiskImageMenu removeAllItems];
    
    NSInteger drivesRightEdge = STATUS_BAR_LEFT_MARGIN;
    NSMutableArray *driveButtons = [NSMutableArray array];
    NSInteger position = 0;
    CardManager &cardManager = GetCardMgr();
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        if (cardManager.QuerySlot(slot) == CT_Disk2) {
            for (int drive = DRIVE_1; drive < NUM_DRIVES; drive++) {
                MarianiDriveButton *driveButton = [MarianiDriveButton buttonForFloppyDrive:drive inSlot:slot];
                [driveButtons addObject:driveButton];
                [self.statusBarView addSubview:driveButton];
                
                // offset each drive light button from the left
                CGRect driveButtonFrame = driveButton.frame;
                driveButtonFrame.origin.x = STATUS_BAR_LEFT_MARGIN + position * [MarianiDriveButton buttonWidth];
                driveButtonFrame.origin.y = STATUS_BAR_BOTTOM_MARGIN;
                driveButton.frame = driveButtonFrame;
                drivesRightEdge = CGRectGetMaxX(driveButtonFrame);
                
                NSString *driveName = [NSString stringWithFormat:NSLocalizedString(@"Slot %d Drive %d", @""), slot, drive + 1];
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:driveName
                                                              action:@selector(openDiskImage:)
                                                       keyEquivalent:@""];
                item.target = driveButton;
                if (slot == SLOT6) {
                    unichar character = (drive == DRIVE_1) ? NSF3FunctionKey : NSF4FunctionKey;
                    NSString *key = [NSString stringWithCharacters:&character length:1];
                    item.keyEquivalent = key;
                    item.keyEquivalentModifierMask = 0;
                }
                [self.openDiskImageMenu addItem:item];
                driveButton.toolTip = driveName;
                
                position++;
            }
        }
    }
    
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        if (cardManager.QuerySlot(slot) == CT_GenericHDD) {
            for (int drive = HARDDISK_1; drive < NUM_HARDDISKS; drive++) {
                HarddiskInterfaceCard *hddCard = dynamic_cast<HarddiskInterfaceCard *>(cardManager.GetObj(slot));
                if (!hddCard->HarddiskGetFullPathName(drive).empty()) {
                    MarianiDriveButton *driveButton = [MarianiDriveButton buttonForHardDrive:drive inSlot:slot];
                    [driveButtons addObject:driveButton];
                    [self.statusBarView addSubview:driveButton];
                    
                    // offset each drive light button from the left
                    CGRect driveButtonFrame = driveButton.frame;
                    driveButtonFrame.origin.x = STATUS_BAR_LEFT_MARGIN + position * [MarianiDriveButton buttonWidth];
                    driveButtonFrame.origin.y = STATUS_BAR_BOTTOM_MARGIN;
                    driveButton.frame = driveButtonFrame;
                    drivesRightEdge = CGRectGetMaxX(driveButtonFrame);
                    
                    NSString *driveName = [NSString stringWithFormat:NSLocalizedString(@"Slot %d Hard Disk %d", @""), slot, drive + 1];
                    driveButton.toolTip = driveName;
                    
                    position++;
                }
            }
        }
    }
    
    self.driveButtons = driveButtons;
    
    CGRect statusLabelFrame = self.statusLabel.frame;
    statusLabelFrame.origin.x = drivesRightEdge + 5;
    statusLabelFrame.size.width = self.screenRecordingButton.frame.origin.x - statusLabelFrame.origin.x - 5;
    self.statusLabel.frame = statusLabelFrame;
    
    if (self.driveButtons.count != oldDriveLightButtonsCount) {
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
        for (MarianiDriveButton *driveButton in self.driveButtons) {
            [driveButton updateDriveLight];
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

- (CGSize)minimumContentSizeAtScale:(double)scale {
    NSSize minimumSize;
    // width of all the things in the status bar...
    minimumSize.width =
        STATUS_BAR_LEFT_MARGIN +
        [MarianiDriveButton buttonWidth] * self.driveButtons.count +           // drive light buttons
        40 +                                                                        // a healthy margin
        (self.window.frame.size.width - self.screenRecordingButton.frame.origin.x); // buttons on the right
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

- (double)windowRectScale {
    Video &video = GetVideo();
    return self.window.frame.size.width / video.GetFrameBufferBorderlessWidth();
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

- (void)setStatus:(nullable NSString *)status {
    self.statusLabel.stringValue = (status != nil) ? status : @"";
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
    NSString *msg = (message != NULL) ? [NSString stringWithUTF8String:message] : @"";
    NSString *info = (information != NULL) ? [NSString stringWithUTF8String:information] : @"";
    return [theAppDelegate showModalAlertofType:type withMessage:msg information:info];
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

const char *GetBuiltinSymbolsDirectory(void) {
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
