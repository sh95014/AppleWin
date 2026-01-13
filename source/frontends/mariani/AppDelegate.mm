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
#import "NSImage+SFSymbols.h"
#import "DebuggerWindowController.h"
#import "UserDefaults.h"

#import "DiskImg.h"
using namespace DiskImgLib;

#define STATUS_BAR_HEIGHT           32
#define STATUS_BAR_DIVIDER_MARGIN   3
#define STATUS_BAR_BOTTOM_MARGIN    1

// needs to match tag of Edit menu item in MainMenu.xib
#define EDIT_TAG            3917

#define BLINK_INTERVAL      0.5 // seconds

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSView *contentBackgroundView;
@property (strong) IBOutlet NSMenu *openDiskImageMenu;
@property (strong) IBOutlet NSMenuItem *editCopyMenu;
@property (strong) IBOutlet NSMenuItem *showHideStatusBarMenuItem;
@property (strong) IBOutlet NSMenu *displayTypeMenu;
@property (strong) IBOutlet NSView *statusBarView;
@property (strong) IBOutlet NSButton *statusBarPowerButton;
@property (strong) IBOutlet NSButton *statusBarResetButton;
@property (strong) IBOutlet NSBox *statusBarDivider;
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
@property CGFloat fullScreenScale;
@property BOOL hadStatusBarWhileWindowed;

@property (strong) NSOpenPanel *tapeOpenPanel;
@property (strong) NSOpenPanel *stateOpenPanel;
@property (strong) NSSavePanel *stateSavePanel;

@property (strong) MemoryViewerWindowController *memoryWC;
@property (strong) DebuggerWindowController *debuggerWC;
@property (strong) DiskMakerWindowController *diskMakerWC;

@property (strong) NSTimer *liveResizeUpdateTimer;
@property (strong) NSTimer *blinkTimer;

@end

static void DiskImgMsgHandler(const char *file, int line, const char *msg);
const NSOperatingSystemVersion macOS12 = { 12, 0, 0 };

@implementation AppDelegate

Disk_Status_e driveStatus[NUM_SLOTS * NUM_DRIVES];

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.processInfo = [[NSProcessInfo alloc] init];
    
    Global::SetDebugMsgHandler(DiskImgMsgHandler);
    Global::AppInit();
    
    _hasStatusBar = [[UserDefaults sharedInstance] showStatusBar];
    if (!self.hasStatusBar) {
        self.statusBarView.hidden = YES;
        [self updateDriveLights];
        self.showHideStatusBarMenuItem.title = NSLocalizedString(@"Show Status Bar", @"");
        
        CGRect contentBackgroundFrame = self.contentBackgroundView.frame;
        contentBackgroundFrame.size.height += STATUS_BAR_HEIGHT;
        contentBackgroundFrame.origin.y -= STATUS_BAR_HEIGHT;
        [self.contentBackgroundView setFrame:contentBackgroundFrame];
    }
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
    
    if (![theAppDelegate.processInfo isOperatingSystemAtLeastVersion:macOS12]) {
        // macOS 11 doesn't have the SF Symbols we want, so fall back to available ones
        self.statusBarPowerButton.image = [NSImage imageWithSystemSymbolName:@"power" accessibilityDescription:@""];
        self.statusBarResetButton.image = [NSImage imageWithSystemSymbolName:@"arrow.counterclockwise" accessibilityDescription:@""];
    }
    else {
        NSImage *customImage = [NSImage largeImageWithSymbolName:@"custom.arrow.trianglehead.2.counterclockwise.circle.fill"];
        if (customImage) {
            self.statusBarResetButton.image = customImage;
        }
    }
    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        const BOOL shift = (event.modifierFlags & NSEventModifierFlagShift) != 0;
        const BOOL control = (event.modifierFlags & NSEventModifierFlagControl) != 0;
        const BOOL option = (event.modifierFlags & NSEventModifierFlagOption) != 0;
        const BOOL command = (event.modifierFlags & NSEventModifierFlagCommand) != 0;
        Video &video = GetVideo();
        switch (event.keyCode) {
            case kVK_F2: {
                [self rebootEmulatorIfConfirmed:self];
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
    
    if (self.window.styleMask & NSWindowStyleMaskFullScreen) {
        // force dark mode because a light mode status bar looks odd in full screen
        NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    }
    
    self.contentBackgroundView.wantsLayer = YES;
#ifdef DEBUG_BLUE_BACKGROUND
    self.contentBackgroundView.layer.backgroundColor = [NSColor systemBlueColor].CGColor;
#else
    self.contentBackgroundView.layer.backgroundColor = [NSColor blackColor].CGColor;
#endif
    
    [self.emulatorVC start];
    
    if ([[UserDefaults sharedInstance] automaticallyCheckForUpdates]) {
        // parameter must be nil for a silent check
        [self checkForUpdates:nil];
    }
    
    // in case user launches straight to full-screen
    self.fullScreenScale = -1;
    self.hadStatusBarWhileWindowed = self.hasStatusBar;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self LogWindowFrame:__PRETTY_FUNCTION__];
    });
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self LogWindowFrame:__PRETTY_FUNCTION__];
    
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

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    // force dark mode because a light mode status bar looks odd in full screen
    NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    
    self.fullScreenScale = -1;
    self.hadStatusBarWhileWindowed = self.hasStatusBar;
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    // restore user-selected light/dark mode
    NSApp.appearance = nil;
    
    // make contentBackgroundView conform to the window we've just sized to
    CGRect contentBackgroundFrame = self.window.contentView.bounds;
    if (self.hasStatusBar) {
        contentBackgroundFrame.origin.y += STATUS_BAR_HEIGHT;
        contentBackgroundFrame.size.height -= STATUS_BAR_HEIGHT;
    }
    [self.contentBackgroundView setFrame:contentBackgroundFrame];
    [self.emulatorVC.view setFrame:self.contentBackgroundView.bounds];
    
    // adopt whatever new scale the user chose while full-screen
    if (self.fullScreenScale > 0) {
        [self.window setFrame:[self windowRectAtScale:self.fullScreenScale] display:YES animate:YES];
    }
    else if (self.hadStatusBarWhileWindowed != self.hasStatusBar) {
        CGRect windowFrame = self.window.frame;
        windowFrame.size.height += self.hadStatusBarWhileWindowed ? -STATUS_BAR_HEIGHT : STATUS_BAR_HEIGHT;
        [self.window setFrame:windowFrame display:YES animate:YES];
    }
}

- (void)windowWillStartLiveResize:(NSNotification *)notification {
    self.liveResizeUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self updateStatusLabelWidthWithOriginX:NAN];
    }];
    [[NSRunLoop currentRunLoop] addTimer:self.liveResizeUpdateTimer forMode:NSRunLoopCommonModes];
}

- (void)windowDidEndLiveResize:(NSNotification *)notification {
    [self.liveResizeUpdateTimer invalidate];
    self.liveResizeUpdateTimer = nil;
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
        NSArray *allowedExtensions = @[ @"WAV", @"WAVE", @"AIFF", @"AIF" ];
        return [allowedExtensions containsObject:url.pathExtension.uppercaseString];
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
    [self startBlinkTimer];
}

- (void)screenRecordingDidStop:(NSURL *)url {
    [self stopBlinkTimer];
    self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle" accessibilityDescription:@""];
    self.screenRecordingButton.contentTintColor = [NSColor secondaryLabelColor];
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Recording saved to ‘%@’", @""), url.path]];
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

- (IBAction)checkForUpdates:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (sender == nil) {
        // not user-initiated
        NSDate *lastUpdateCheckDate = [[UserDefaults sharedInstance] lastUpdateCheckDate];
        if (lastUpdateCheckDate != nil &&                                       // never checked
            [lastUpdateCheckDate timeIntervalSinceNow] > -30 * 24 * 60 * 60) {  // checked over 30 days ago
            NSLog(@"Skip, last check only %f seconds ago", -[lastUpdateCheckDate timeIntervalSinceNow]);
            return;
        }
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        enum {
            UP_TO_DATE, UPDATE_AVAILABLE, UNEXPECTED_RESPONSE, FETCH_ERROR,
        } updateAction = UNEXPECTED_RESPONSE;
        NSString *updateURLString = nil;
        NSURL *url = [NSURL URLWithString:@"https://api.github.com/repos/sh95014/AppleWin/releases/latest"];
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error == nil) {
            if ([object isKindOfClass:[NSDictionary class]]) {
                NSDictionary *results = object;
                if (![[results objectForKey:@"prerelease"] boolValue]) {
                    // "prerelease": false
                    if ((updateURLString = [[results objectForKey:@"html_url"] stringValue]) != nil) {
                        // "html_url": "https://...",
                        NSString *latestReleaseString = [[results objectForKey:@"name"] stringValue];
                        // e.g., "name": "Mariani 1.5 (2)" => ["Mariani", "1.5", "(2)"]
                        NSArray *latestReleaseParts = [latestReleaseString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        if (latestReleaseParts.count == 3) {
                            // e.g., "1.5" => ["1", "5"]
                            NSArray<NSString *> *latestVersionParts = [latestReleaseParts[1] componentsSeparatedByString:@"."];
                            // e.g., "(2)" => "2"
                            NSCharacterSet *parentheses = [NSCharacterSet characterSetWithCharactersInString:@"()"];
                            NSString *latestBuildString = [latestReleaseParts[2] stringByTrimmingCharactersInSet:parentheses];
                            
                            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
                            NSString *myVersionString = infoDictionary[@"CFBundleShortVersionString"];
                            NSArray<NSString *> *myVersionParts = [myVersionString componentsSeparatedByString:@"."];
                            NSString *myBuildString = infoDictionary[@"CFBundleVersion"];
                            
                            NSInteger latestVersion =
                                latestVersionParts[0].integerValue * 1000000 +
                                latestVersionParts[1].integerValue * 1000 +
                                latestBuildString.integerValue;
                            NSInteger myVersion =
                                myVersionParts[0].integerValue * 1000000 +
                                myVersionParts[1].integerValue * 1000 +
                                myBuildString.integerValue;
                            
                            NSLog(@"Latest version: %ld.%ld (%ld)",
                                  latestVersionParts[0].integerValue,
                                  latestVersionParts[1].integerValue,
                                  latestBuildString.integerValue);
                            updateAction = (latestVersion > myVersion) ? UPDATE_AVAILABLE : UP_TO_DATE;
                            [[UserDefaults sharedInstance] setLastUpdateCheckDate:[NSDate now]];
                        }
                        else {
                            NSLog(@"Unexpected version '%@'", latestReleaseString);
                        }
                    }
                    else {
                        NSLog(@"Unexpected html_url");
                    }
                }
            }
            else {
                NSLog(@"Unexpected data format");
            }
        }
        else {
            updateAction = FETCH_ERROR;
            NSLog(@"Error: %@", error.localizedDescription);
        }
        if (updateAction == UPDATE_AVAILABLE || sender != nil) {
            // pop a dialog if updates are available, or if this was initiated
            // by the user from the menu.
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                
                switch (updateAction) {
                    case UP_TO_DATE:
                        alert.messageText = NSLocalizedString(@"Up-to-Date", @"");
                        alert.informativeText = NSLocalizedString(@"No newer version of this software is available.", @"");
                        alert.alertStyle = NSAlertStyleInformational;
                        alert.icon = [NSImage imageWithSystemSymbolName:@"hand.thumbsup" accessibilityDescription:@""];
                        break;
                    case UPDATE_AVAILABLE:
                        alert.messageText = NSLocalizedString(@"Update Available", @"");
                        alert.informativeText = NSLocalizedString(@"A newer version of this software is available.", @"");
                        alert.alertStyle = NSAlertStyleInformational;
                        alert.icon = [NSImage imageWithSystemSymbolName:@"square.and.arrow.down" accessibilityDescription:@""];
                        [alert addButtonWithTitle:NSLocalizedString(@"Download…", @"")];
                        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
                        break;
                    case UNEXPECTED_RESPONSE:
                        alert.messageText = NSLocalizedString(@"Error", @"");
                        alert.informativeText = NSLocalizedString(@"Unexpected server response", @"");
                        alert.alertStyle = NSAlertStyleWarning;
                        alert.icon = [NSImage imageWithSystemSymbolName:@"exclamationmark.triangle" accessibilityDescription:@""];
                        break;
                    case FETCH_ERROR:
                        alert.messageText = NSLocalizedString(@"Error", @"");
                        alert.informativeText = error.localizedDescription;
                        alert.alertStyle = NSAlertStyleWarning;
                        alert.icon = [NSImage imageWithSystemSymbolName:@"exclamationmark.triangle" accessibilityDescription:@""];
                        break;
                }
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSAlertFirstButtonReturn) {
                        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:updateURLString]];
                    }
                }];
            });
        }
    });
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

- (IBAction)terminateIfConfirmed:(id)sender {
    NSLog(@"Terminating due to ⌘Q...");
    [self windowShouldClose:self.window];
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
        NSLog(@"loaded %lu bytes", (unsigned long)audioData.size());
        
        std::string filename(self.tapeOpenPanel.URL.lastPathComponent.UTF8String);
        CassetteTape::instance().setData(filename,
                                         audioData,
                                         outputFormat.mSampleRate);
        
        ExtAudioFileDispose(inputFile);
        self.tapeOpenPanel = nil;
        [self reconfigureDrives];
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
    [[UserDefaults sharedInstance] setShowStatusBar:_hasStatusBar];
    self.statusBarView.hidden = !_hasStatusBar;
    [self updateDriveLights];
    
    CGRect contentBackgroundFrame = self.contentBackgroundView.frame;
    CGRect windowFrame = self.window.frame;
    if (self.window.styleMask & NSWindowStyleMaskFullScreen) {
        contentBackgroundFrame = windowFrame;
        if (self.hasStatusBar) {
            contentBackgroundFrame.size.height -= STATUS_BAR_HEIGHT;
            contentBackgroundFrame.origin.y += STATUS_BAR_HEIGHT;
        }
    }
    else {
        // windowed
        const double statusBarHeight = STATUS_BAR_HEIGHT;
        if (self.hasStatusBar) {
            contentBackgroundFrame.origin.y = statusBarHeight;
            windowFrame.size.height += statusBarHeight;
            windowFrame.origin.y -= statusBarHeight;
        }
        else {
            contentBackgroundFrame.origin.y = 0;
            windowFrame.size.height -= statusBarHeight;
            windowFrame.origin.y += statusBarHeight;
        }
        
        // need to resize the window before the emulator view because the window
        // tries to resize its children when it's being resized.
        [self.window setFrame:windowFrame display:YES animate:NO];
    }
    self.showHideStatusBarMenuItem.title = self.hasStatusBar ?
        NSLocalizedString(@"Hide Status Bar", @"") :
        NSLocalizedString(@"Show Status Bar", @"");
    [self.contentBackgroundView setFrame:contentBackgroundFrame];
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
    [self setWindowScale:1.5];
}

- (IBAction)actualSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self setWindowScale:1];
}

- (IBAction)doubleSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self setWindowScale:2];
}

- (IBAction)increaseSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (self.window.styleMask & NSWindowStyleMaskFullScreen) {
        double scale = self.emulatorVC.view.frame.size.width / GetVideo().GetFrameBufferBorderlessWidth();
        [self setWindowScale:scale * 1.2];
    }
    else {
        [self scaleWindowByFactor:1.2];
    }
}

- (IBAction)decreaseSizeAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (self.window.styleMask & NSWindowStyleMaskFullScreen) {
        double scale = 0.8 * (self.emulatorVC.view.frame.size.width / GetVideo().GetFrameBufferBorderlessWidth());
        if (scale < 1) {
            scale = 1;
        }
        [self setWindowScale:scale];
    }
    else {
        [self scaleWindowByFactor:0.8];
    }
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
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Screenshot saved to ‘%@’", @""), url.path]];
}

#pragma mark - Status bar actions

- (IBAction)rebootEmulatorIfConfirmed:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    
    alert.messageText = NSLocalizedString(@"Reboot?", @"");
    alert.informativeText = NSLocalizedString(@"This will restart the emulation and any unsaved changes will be lost.", @"");
    alert.alertStyle = NSAlertStyleWarning;
    alert.icon = [NSImage imageWithSystemSymbolName:@"hand.raised" accessibilityDescription:@""];
    [alert addButtonWithTitle:NSLocalizedString(@"Reboot Emulator", @"")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self rebootEmulatorAction:self];
        }
    }];
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
    
    const NSInteger statusBarLeftMargin = CGRectGetMaxX(self.statusBarDivider.frame) + STATUS_BAR_DIVIDER_MARGIN;
    
    NSInteger drivesRightEdge = statusBarLeftMargin;
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
                driveButtonFrame.origin.x = statusBarLeftMargin + position * [MarianiDriveButton buttonWidth];
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
                    driveButtonFrame.origin.x = statusBarLeftMargin + position * [MarianiDriveButton buttonWidth];
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
    
    // add an icon for a loaded cassette tape with filename as tooltip
    CassetteTape::TapeInfo tapeInfo;
    CassetteTape::instance().getTapeInfo(tapeInfo);
    if (tapeInfo.filename.length() > 0) {
        MarianiDriveButton *tapeButton = [MarianiDriveButton buttonForTape];
        [driveButtons addObject:tapeButton];
        [self.statusBarView addSubview:tapeButton];
        
        CGRect tapeButtonFrame = tapeButton.frame;
        tapeButtonFrame.origin.x = statusBarLeftMargin + position * [MarianiDriveButton buttonWidth];
        tapeButtonFrame.origin.y = STATUS_BAR_BOTTOM_MARGIN;
        tapeButton.frame = tapeButtonFrame;
        drivesRightEdge = CGRectGetMaxX(tapeButtonFrame);
        
        tapeButton.toolTip = [NSString stringWithCString:tapeInfo.filename.data() encoding:NSUTF8StringEncoding];
    }
    
    self.driveButtons = driveButtons;
    
    [self updateStatusLabelWidthWithOriginX:drivesRightEdge + 5];
    
    if (self.driveButtons.count != oldDriveLightButtonsCount) {
        // constrain our window to not allow it to be resized so small that our
        // status bar buttons overlap
        [self.window setContentMinSize:[self minimumWindowSizeAtScale:1]];
    }
    
    [self updateDriveLights];
}

- (void)updateStatusLabelWidthWithOriginX:(CGFloat)x {
    CGRect statusLabelFrame = self.statusLabel.frame;
    if (!isnan(x)) {
        statusLabelFrame.origin.x = x;
    }
    statusLabelFrame.size.width = self.screenRecordingButton.frame.origin.x - statusLabelFrame.origin.x - 5;
    self.statusLabel.frame = statusLabelFrame;
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

- (void)setWindowScale:(double)scale {
    if (self.window.styleMask & NSWindowStyleMaskFullScreen) {
        // center the EmulatorView inside contentBackgroundView at the specified size
        CGSize availSize = self.contentBackgroundView.bounds.size;
        
        Video &video = GetVideo();
        CGFloat width = video.GetFrameBufferBorderlessWidth() * scale;
        CGFloat height = video.GetFrameBufferBorderlessHeight() * scale;
        
        self.fullScreenScale = scale;
        if (width > availSize.width || height > availSize.height) {
            // clamp to availRect, preserving aspect ratio
            CGFloat aspectRatio = MIN(availSize.width / width, availSize.height / height);
            width *= aspectRatio;
            height *= aspectRatio;
            self.fullScreenScale = width / video.GetFrameBufferBorderlessWidth();
        }
        CGRect frame = CGRectMake(floorf((availSize.width - width) / 2),
                                  floorf((availSize.height - height) / 2),
                                  width,
                                  height);
        [self.emulatorVC.view setFrame:frame];
    }
    else {
        CGRect frame = [self windowRectAtScale:scale];
        [self.window setFrame:frame display:YES animate:NO];
        [self updateStatusLabelWidthWithOriginX:NAN];
    }
}

- (CGSize)minimumWindowSizeAtScale:(double)scale {
    NSSize minimumSize;
    // width of all the things in the status bar...
    const NSInteger statusBarLeftMargin = CGRectGetMaxX(self.statusBarDivider.frame) + STATUS_BAR_DIVIDER_MARGIN;
    minimumSize.width =
        statusBarLeftMargin +
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
    frame.size = [self minimumWindowSizeAtScale:scale];
    frame.size.height += windowFrame.size.height - contentFrame.size.height;  // window chrome?

    // center the new window at the center of the old one
    frame.origin.x = windowFrame.origin.x + (windowFrame.size.width - frame.size.width) / 2;
    frame.origin.y = windowFrame.origin.y + (windowFrame.size.height - frame.size.height) / 2;
    
    return frame;
}

- (double)windowRectScale {
    Video &video = GetVideo();
    double horizontalRatio = self.emulatorVC.view.frame.size.width / video.GetFrameBufferBorderlessWidth();
    double verticalRatio = self.emulatorVC.view.frame.size.height / video.GetFrameBufferBorderlessHeight();
    // because we scale the emulated screen to fit the window,
    // the effective scale is the smaller of the two.
    return MIN(horizontalRatio, verticalRatio);
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
    CGSize minimumSize = [self minimumWindowSizeAtScale:1];
    if (frame.size.width < minimumSize.width || frame.size.height < minimumSize.height) {
        frame.size = minimumSize;
    }
    
    frame.size.height += windowFrame.size.height - contentFrame.size.height;  // window chrome?
    
    // center the new window at the center of the old one
    frame.origin.x = windowFrame.origin.x + (windowFrame.size.width - frame.size.width) / 2;
    frame.origin.y = windowFrame.origin.y + (windowFrame.size.height - frame.size.height) / 2;
    
    [self.window setFrame:frame display:YES animate:NO];
    [self updateStatusLabelWidthWithOriginX:NAN];
}

- (void)setStatus:(nullable NSString *)status {
    self.statusLabel.stringValue = (status != nil) ? status : @"";
}

- (double)statusBarHeight {
    return self.hasStatusBar ? STATUS_BAR_HEIGHT : 0;
}

- (void)LogWindowFrame:(const char *)context {
    const CGRect windowFrame = self.window.frame;
    NSLog(@"%s: window.frame = { %.1f, %.1f, %.1f, %.1f }",
          context,
          windowFrame.origin.x, windowFrame.origin.y,
          windowFrame.size.width, windowFrame.size.height);
}

- (void)startBlinkTimer {
    if (!self.blinkTimer) {
        [self tick];
    }
}

- (void)tick {
    if (theAppDelegate.emulatorVC.isRecordingScreen) {
        self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle.fill" accessibilityDescription:@""];
    }
    self.blinkTimer = [NSTimer scheduledTimerWithTimeInterval:BLINK_INTERVAL target:self selector:@selector(tock) userInfo:nil repeats:NO];
}

- (void)tock {
    if (theAppDelegate.emulatorVC.isRecordingScreen) {
        self.screenRecordingButton.image = [NSImage imageWithSystemSymbolName:@"record.circle" accessibilityDescription:@""];
    }
    self.blinkTimer = [NSTimer scheduledTimerWithTimeInterval:BLINK_INTERVAL target:self selector:@selector(tick) userInfo:nil repeats:NO];
}

- (void)stopBlinkTimer {
    if (theAppDelegate.emulatorVC.isRecordingScreen) {
        return;
    }
    [self.blinkTimer invalidate];
    self.blinkTimer = nil;
}

@end

#pragma mark - C++ Helpers

// These are needed because AppleWin redeclares BOOL in wincompat.h, so
// MarianiFrame can't be compile as Objective-C++ to call these methods
// itself.

void VideoRefresh(void) {
    [theAppDelegate.emulatorVC refreshTexture];
}

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
