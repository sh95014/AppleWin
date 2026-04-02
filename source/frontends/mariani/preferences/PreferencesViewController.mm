//
//  PreferencesViewController.mm
//  Mariani
//
//  Created by sh95014 on 12/30/21.
//

// This controller handles all the preferences panes, but there's one instance
// created per pane. When necessary they use the "vcId" user-defined run-time
// attribute to disambiguate.

#import <GameController/GameController.h>
#import "PreferencesViewController.h"
#import "AppDelegate.h"
#import "DiskMakerWindowController.h"
#import "UserDefaults.h"
#import "SlotPreferencesViewControllers.h"

// AppleWin
#include "StdAfx.h"
#import <string>

#import "winhandles.h"
#import "Card.h"
#import "CardManager.h"
#import "Common.h"
#import "Core.h"
#import "Disk.h"
#import "Harddisk.h"
#import "Interface.h"
#import "Memory.h"
void CreateLanguageCard(void); // FIXME should be in Memory.h
#import "Mockingboard.h"
#import "Speaker.h"
#ifndef U2_USE_SLIRP
#import "PCapBackend.h"
#endif
#import "tfesupp.h"

// Objective-C typedefs BOOL to be bool, but wincompat.h typedefs it to be
// int32_t, which causes function signature mismatches (such as with the
// RegSaveValue() calls below.) This hack allows the function to be seen
// with the correct signature and avoids the link error.
#define BOOL int32_t
#import "Registry.h"
#undef BOOL

#include "DiskImg.h"
using namespace DiskImgLib;

// these need to match the values set in Preferences.storyboard for key "vcId"
#define GENERAL_PANE_ID         @"general"
#define COMPUTER_PANE_ID        @"computer"
#define AUDIO_VIDEO_PANE_ID     @"audioVideo"
#define STORAGE_PANE_ID         @"storage"
#define GAME_CONTROLLER_ID      @"gameController"

@interface PreferencesViewController ()

@property (strong) IBOutlet NSButton *generalScreenshotsFolderButton;
@property (strong) IBOutlet NSButton *generalRecordingsFolderButton;
@property (strong) IBOutlet NSPopUpButton *generalRecordingQualityButton;
@property (strong) IBOutlet NSButton *generalMapDeleteKeyToLeftArrowButton;
@property (strong) IBOutlet NSButton *generalTakeScreenshotsBasedOnWindowSize;
@property (strong) IBOutlet NSButton *generalAutomaticallyCheckForUpdates;

@property (strong) IBOutlet NSPopUpButton *computerMainBoardButton;

@property (strong) IBOutlet NSPopUpButton *computerSlot0Button;
@property (strong) IBOutlet NSButton *computerSlot0MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerSlot1Button;
@property (strong) IBOutlet NSButton *computerSlot1MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerSlot2Button;
@property (strong) IBOutlet NSButton *computerSlot2MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerSlot3Button;
@property (strong) IBOutlet NSButton *computerSlot3MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerSlot4Button;
@property (strong) IBOutlet NSButton *computerSlot4MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerSlot5Button;
@property (strong) IBOutlet NSButton *computerSlot5MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerSlot6Button;
@property (strong) IBOutlet NSButton *computerSlot6MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerSlot7Button;
@property (strong) IBOutlet NSButton *computerSlot7MoreButton;
@property (strong) IBOutlet NSPopUpButton *computerExansionSlotButton;
@property (strong) IBOutlet NSButton *computerExpansionSlotMoreButton;
@property (strong) IBOutlet NSPopUpButton *computerPcapSlotButton;
@property (strong) IBOutlet NSPopUpButton *computerCopyProtectionDongleButton;
@property (strong) IBOutlet NSButton *computerRebootEmulatorButton;

@property (strong) IBOutlet NSButton *video50PercentScanLinesButton;
@property (strong) IBOutlet NSColorWell *videoCustomColorWell;
@property (strong) IBOutlet NSSlider *audioSpeakerVolumeSlider;
@property (strong) IBOutlet NSSlider *audioMockingboardVolumeSlider;

@property (strong) IBOutlet NSButton *storageEnhancedSpeedButton;
@property (strong) IBOutlet NSTableView *storageHardDiskTableView;
@property (strong) IBOutlet NSButton *storageHardDiskAddButton;
@property (strong) IBOutlet NSButton *storageHardDiskDeleteButton;
@property (strong) IBOutlet NSButton *storageCreateHardDiskButton;

@property (weak) IBOutlet NSPopUpButton *gameController;
@property (weak) IBOutlet NSPopUpButton *gameControllerJoystick;
@property (weak) IBOutlet NSPopUpButton *gameControllerButton0;
@property (weak) IBOutlet NSPopUpButton *gameControllerButton1;

@property (strong) NSPopover *morePopover;

@property NSMutableDictionary *keyValueStore;
@property BOOL configured;
@property (strong) DiskMakerWindowController *diskMakerWC;

@end

@implementation PreferencesViewController

BOOL configured;

- (void)awakeFromNib {
    // each pane's controller should only configure itself
    if (!self.configured) {
        NSString *vcId = [self valueForKey:@"vcId"];
        if ([vcId isEqualToString:GENERAL_PANE_ID]) {
            [self configureGeneral];
        }
        if ([vcId isEqualToString:COMPUTER_PANE_ID]) {
            [self configureComputer];
        }
        else if ([vcId isEqualToString:AUDIO_VIDEO_PANE_ID]) {
            [self configureAudio];
            [self configureVideo];
        }
        else if ([vcId isEqualToString:STORAGE_PANE_ID]) {
            [self configureStorage];
        }
        else if ([vcId isEqualToString:GAME_CONTROLLER_ID]) {
            [self configureGameController];
        }
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(updateGameControllers) name:GCControllerDidConnectNotification object:nil];
        [center addObserver:self selector:@selector(updateGameControllers) name:GCControllerDidDisconnectNotification object:nil];

        self.configured = YES;
    }
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if (self.keyValueStore == nil) {
        self.keyValueStore = [NSMutableDictionary dictionary];
    }
    [self.keyValueStore setValue:value forKey:key];
}

- (id)valueForKey:(NSString *)key {
    return [self.keyValueStore valueForKey:key];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // causes the preferences window to resize depending on the preferred size
    // of each pane
    self.preferredContentSize = self.view.frame.size;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    self.view.window.title = self.title;
}

#pragma mark - Configuration

- (void)configureGeneral {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSURL *folder = [[UserDefaults sharedInstance] screenshotsFolder];
    self.generalScreenshotsFolderButton.title = [folder.path stringByAbbreviatingWithTildeInPath];

    folder = [[UserDefaults sharedInstance] recordingsFolder];
    self.generalRecordingsFolderButton.title = [folder.path stringByAbbreviatingWithTildeInPath];

    const NSInteger quality = [[UserDefaults sharedInstance] recordingQuality];
    [self.generalRecordingQualityButton selectItemWithTag:quality];

    self.generalMapDeleteKeyToLeftArrowButton.state = [UserDefaults sharedInstance].mapDeleteKeyToLeftArrow ? NSControlStateValueOn : NSControlStateValueOff;
    self.generalTakeScreenshotsBasedOnWindowSize.state = [UserDefaults sharedInstance].takeScreenshotsBasedOnWindowSize ? NSControlStateValueOn : NSControlStateValueOff;
    self.generalAutomaticallyCheckForUpdates.state = [UserDefaults sharedInstance].automaticallyCheckForUpdates ? NSControlStateValueOn : NSControlStateValueOff;
}

// types of main boards, ordered as we want them to appear in UI
const eApple2Type computerTypes[] = {
    A2TYPE_APPLE2, A2TYPE_APPLE2PLUS, A2TYPE_APPLE2JPLUS, A2TYPE_APPLE2E,
    A2TYPE_APPLE2EENHANCED, A2TYPE_PRAVETS82, A2TYPE_PRAVETS8M,
    A2TYPE_PRAVETS8A, A2TYPE_TK30002E, A2TYPE_BASE64A
};

- (void)configureComputer {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    // emulation computer types
    NSString *vcId = [self valueForKey:@"vcId"];
    if ([vcId isEqualToString:COMPUTER_PANE_ID]) {
        const eApple2Type computerType = GetApple2Type();

        NSDictionary *map = [self localizedComputerNameMap];
        for (NSInteger i = 0; i < sizeof(computerTypes) / sizeof (*computerTypes); i++) {
            [self.computerMainBoardButton addItemWithTitle:[map objectForKey:@(computerTypes[i])]];
            if (computerType == computerTypes[i]) {
                [self.computerMainBoardButton selectItemAtIndex:i];
            }
        }
    
        [self configureSlots];
        
#ifndef U2_USE_SLIRP
        // pcap
        if (PCapBackend::tfe_enumadapter_open()) {
            std::string name;
            std::string description;
            
            while (PCapBackend::tfe_enumadapter(name, description)) {
                [self.computerPcapSlotButton addItemWithTitle:[NSString stringWithUTF8String:name.c_str()]];
            }
            PCapBackend::tfe_enumadapter_close();
            
            [self.computerPcapSlotButton selectItemWithTitle:[NSString stringWithUTF8String:PCapBackend::GetRegistryInterface(SLOT3).c_str()]];
        }
#else
        self.computerPcapSlotButton.enabled = false;
#endif // U2_USE_SLIRP
        
        // copy protection
        NSDictionary *dongleNames = [self.class localizedCopyProtectionDongleNameMap];
        for (int i = DT_EMPTY; i <= DT_HAYDENCOMPILER; i++) {
            [self.computerCopyProtectionDongleButton addItemWithTitle:[dongleNames objectForKey:@(i)]];
        }
        [self.computerCopyProtectionDongleButton selectItemAtIndex:GetCopyProtectionDongleType()];
    }
}

- (void)configureSlots {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    const eApple2Type computerType = GetApple2Type();
    CardManager &manager = GetCardMgr();
    NSDictionary *cardNames = [self.class localizedCardNameMap];
    
    SS_CARDTYPE currConfig[NUM_SLOTS];
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        currConfig[slot] = manager.QuerySlot(slot);
    }
    
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        NSPopUpButton *slotButton = [[self slotButtonsArray] objectAtIndex:slot];
        NSButton *slotMoreButton = [[self slotMoreButtonsArray] objectAtIndex:slot];
        
        [slotButton removeAllItems];
        
        if (slot == SLOT0 && !IsApple2PlusOrClone(computerType)) {
            // only Apple ][+ or clones have a configurable slot 0
            slotButton.enabled = NO;
            slotMoreButton.enabled = NO;
            continue;
        }
        
        // already set up that way in Preferences.storyboard but let's be
        // explicit because slotAction: and slotMoreAction: rely on it.
        slotButton.tag = slot;
        slotMoreButton.tag = slot;
        
        std::string choices;
        std::vector<SS_CARDTYPE> choicesList;
        manager.GetCardChoicesForSlot(slot, currConfig, choices, choicesList);
        
        for (const SS_CARDTYPE& cardType : choicesList) {
            [slotButton addItemWithTitle:[cardNames objectForKey:@(cardType)]];
            slotButton.lastItem.tag = cardType;
        }
        
        // show the current item as selected
        const SS_CARDTYPE selectedCard = manager.QuerySlot(slot);
        [slotButton selectItemWithTag:selectedCard];
        
        slotButton.enabled = YES;
        slotMoreButton.enabled = [self cardTypeHasOptions:selectedCard];
    }
    
    [self.computerExansionSlotButton removeAllItems];
    if (IsAppleIIe(computerType)) {
        // expansion slot
        std::string choices;
        std::vector<SS_CARDTYPE> choicesList;
        manager.GetCardChoicesForAuxSlot(choices, choicesList);
        
        for (const SS_CARDTYPE& cardType : choicesList) {
            [self.computerExansionSlotButton addItemWithTitle:[cardNames objectForKey:@(cardType)]];
            self.computerExansionSlotButton.lastItem.tag = cardType;
        }
        
        // show the current item as selected
        const SS_CARDTYPE selectedCard = GetCurrentExpansionMemType();
        [self.computerExansionSlotButton selectItemWithTag:selectedCard];
        
        self.computerExansionSlotButton.enabled = YES;
        self.computerExpansionSlotMoreButton.enabled = [self cardTypeHasOptions:selectedCard];
    }
    else {
        self.computerExansionSlotButton.enabled = NO;
        self.computerExpansionSlotMoreButton.enabled = NO;
    }
}

- (void)configureAudio {
    // speaker volume slider. for some reason lower numbers are quieter so we
    // need to get the complements
    NSString *vcId = [self valueForKey:@"vcId"];
    if ([vcId isEqualToString:AUDIO_VIDEO_PANE_ID]) {
        const int volumeMax = GetPropertySheet().GetVolumeMax();
        self.audioSpeakerVolumeSlider.maxValue = volumeMax;
        self.audioSpeakerVolumeSlider.intValue = volumeMax - SpkrGetVolume();
        
        // Mockingboard volume slider
        CardManager &cardManager = GetCardMgr();
        self.audioMockingboardVolumeSlider.maxValue = volumeMax;
        self.audioMockingboardVolumeSlider.intValue = volumeMax - cardManager.GetMockingboardCardMgr().GetVolume();
        [self performSelector:@selector(updateMockingboardPreferences) inViewControllerWithID:AUDIO_VIDEO_PANE_ID];
    }
}

- (void)updateMockingboardPreferences {
    self.audioMockingboardVolumeSlider.enabled = [self isMockingboardInstalled];
}

- (void)configureVideo {
    NSString *vcId = [self valueForKey:@"vcId"];
    if ([vcId isEqualToString:AUDIO_VIDEO_PANE_ID]) {
        Video &video = GetVideo();

        // Custom Monochrome color
        self.videoCustomColorWell.color = [self colorWithColorRef:video.GetMonochromeRGB()];
        
        // 50% Scan Lines
        self.video50PercentScanLinesButton.state = video.IsVideoStyle(VS_HALF_SCANLINES) ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

- (void)configureStorage {
    NSString *vcId = [self valueForKey:@"vcId"];
    if ([vcId isEqualToString:STORAGE_PANE_ID]) {
        CardManager &cardManager = GetCardMgr();

        // Enhanced speed for floppy drives
        self.storageEnhancedSpeedButton.state = cardManager.GetDisk2CardMgr().GetEnhanceDisk() ? NSControlStateValueOn : NSControlStateValueOff;

        self.storageHardDiskTableView.delegate = self;
        self.storageHardDiskTableView.dataSource = self;

        [self performSelector:@selector(updateHardDiskPreferences) inViewControllerWithID:STORAGE_PANE_ID];
    }
}

- (void)updateHardDiskPreferences {
    HarddiskInterfaceCard *hddCard = [self hddCard];
    if (hddCard != nil) {
        self.storageHardDiskTableView.enabled = YES;
        self.storageCreateHardDiskButton.enabled = YES;
        
        [self.storageHardDiskTableView reloadData];
        int count = 0;
        for (int i = HARDDISK_1; i < NUM_HARDDISKS; i++) {
            count += !hddCard->HarddiskGetFullPathName(i).empty();
        }
        // with no selection, enable "+" button if an empty slot is available
        self.storageHardDiskAddButton.enabled = (count < NUM_HARDDISKS);
        // with no selection, nothing to delete
        self.storageHardDiskDeleteButton.enabled = NO;
    }
    else {
        self.storageHardDiskTableView.enabled = NO;
        self.storageCreateHardDiskButton.enabled = NO;
        self.storageHardDiskAddButton.enabled = NO;
        self.storageHardDiskDeleteButton.enabled = NO;
    }
    [self.storageHardDiskTableView reloadData];
}

- (void)configureGameController {
    NSString *vcId = [self valueForKey:@"vcId"];
    if ([vcId isEqualToString:GAME_CONTROLLER_ID]) {
        [self updateGameControllers];
        
        UserDefaults *defaults = [UserDefaults sharedInstance];
        [self.gameControllerJoystick addItemsWithTitles:defaults.joystickOptions];
        [self.gameControllerJoystick selectItemAtIndex:defaults.joystickMapping];
        [self.gameControllerButton0 addItemsWithTitles:defaults.joystickButtonOptions];
        [self.gameControllerButton0 selectItemAtIndex:defaults.joystickButton0Mapping];
        [self.gameControllerButton1 addItemsWithTitles:defaults.joystickButtonOptions];
        [self.gameControllerButton1 selectItemAtIndex:defaults.joystickButton1Mapping];
    }
}

- (void)updateGameControllers {
    // GameControllerNone
    [self.gameController removeAllItems];
    [self.gameController addItemWithTitle:NSLocalizedString(@"None", @"")];
    for (GCController *controller in [GCController controllers]) {
        GCExtendedGamepad *gamePad = controller.extendedGamepad;
        if (gamePad != nil) {
            [self.gameController addItemWithTitle:controller.fullName];
        }
    }
    // GameControllerNumericKeypad
    [self.gameController addItemWithTitle:NSLocalizedString(@"Numeric Keypad", @"")];
    
    UserDefaults *defaults = [UserDefaults sharedInstance];
    if ([defaults.gameController isEqualToString:GameControllerNone]) {
        [self.gameController selectItemAtIndex:0];
        self.gameControllerJoystick.enabled = NO;
        self.gameControllerButton0.enabled = NO;
        self.gameControllerButton1.enabled = NO;
    }
    else if ([defaults.gameController isEqualToString:GameControllerNumericKeypad]) {
        [self.gameController selectItem:self.gameController.lastItem];
        self.gameControllerJoystick.enabled = NO;
        self.gameControllerButton0.enabled = NO;
        self.gameControllerButton1.enabled = NO;
    }
    else {
        [self.gameController selectItemWithTitle:defaults.gameController];
        self.gameControllerJoystick.enabled = YES;
        self.gameControllerButton0.enabled = YES;
        self.gameControllerButton1.enabled = YES;
    }
}

#pragma mark - Actions

- (IBAction)toggleMapDeleteKeyToLeftArrow:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    BOOL mapDeleteKeyToLeftArrow = [UserDefaults sharedInstance].mapDeleteKeyToLeftArrow;
    [UserDefaults sharedInstance].mapDeleteKeyToLeftArrow = !mapDeleteKeyToLeftArrow;
}

- (IBAction)toggleTakeScreenshotsBasedOnWindowSize:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    BOOL takeScreenshotsBasedOnWindowSize = [UserDefaults sharedInstance].takeScreenshotsBasedOnWindowSize;
    [UserDefaults sharedInstance].takeScreenshotsBasedOnWindowSize = !takeScreenshotsBasedOnWindowSize;
}

- (IBAction)toggleAutomaticallyCheckForUpdates:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    BOOL automaticallyCheckForUpdates = [UserDefaults sharedInstance].automaticallyCheckForUpdates;
    [UserDefaults sharedInstance].automaticallyCheckForUpdates = !automaticallyCheckForUpdates;
}

- (IBAction)recordingsFolderAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.canDownloadUbiquitousContents = YES;
    panel.message = NSLocalizedString(@"Select folder to save screen recordings into", @"");
    
    if ([panel runModal] == NSModalResponseOK) {
        self.generalRecordingsFolderButton.title = [panel.URL.path stringByAbbreviatingWithTildeInPath];
        [[UserDefaults sharedInstance] setRecordingsFolder:panel.URL];
    }
}

- (IBAction)screenshotsFolderAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.canDownloadUbiquitousContents = YES;
    panel.message = NSLocalizedString(@"Select folder to save screenshots into", @"");
    
    if ([panel runModal] == NSModalResponseOK) {
        self.generalScreenshotsFolderButton.title = [panel.URL.path stringByAbbreviatingWithTildeInPath];
        [[UserDefaults sharedInstance] setScreenshotsFolder:panel.URL];
    }
}

- (IBAction)recordingQualityAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSInteger tag = self.generalRecordingQualityButton.selectedTag;
    [[UserDefaults sharedInstance] setRecordingQuality:tag];
}

- (IBAction)mainBoardAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSInteger index = [self.computerMainBoardButton indexOfSelectedItem];
    SetApple2Type(computerTypes[index]);
    RegSaveValue(REG_CONFIG, REGVALUE_APPLE2_TYPE, true, computerTypes[index]);
    NSLog(@"Set main board type to '%@' (%d)",
          [[self localizedComputerNameMap] objectForKey:@(computerTypes[index])],
          computerTypes[index]);
    
    self.computerRebootEmulatorButton.enabled = [theAppDelegate emulationHardwareChanged];
    
    // main board affects which slots are available
    [self configureSlots];
}

- (IBAction)slotAction:(id)sender {
    NSLog(@"%s (%ld)", __PRETTY_FUNCTION__, (long)[(NSView *)sender tag]);
    
    if ([sender isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *slotButton = (NSPopUpButton *)sender;
        const NSInteger currentSlot = slotButton.tag;
        
        CardManager &cardManager = GetCardMgr();
        Video &video = GetVideo();
        
        // special teardown if a VidHD card was removed
        const BOOL oldHasVidHD = video.HasVidHD();
        const BOOL newHasVidHD = (slotButton.selectedTag == CT_VidHD);
        if (oldHasVidHD == YES && newHasVidHD == NO) {
            video.SetVidHD(false);
        }
        
        const SS_CARDTYPE previousCard = cardManager.QuerySlot((SLOTS)currentSlot);
        
        cardManager.Insert((SLOTS)currentSlot, (SS_CARDTYPE)slotButton.selectedTag);
        
        MemInitializeIO();
        
        [theAppDelegate reconfigureDrives];
        if (oldHasVidHD != video.HasVidHD()) {
            [theAppDelegate reinitializeFrame];
        }
        
        // update related settings in other panes as necessary
        if (previousCard == CT_GenericHDD || cardManager.QuerySlot((SLOTS)currentSlot) == CT_GenericHDD) {
            [self performSelector:@selector(updateHardDiskPreferences) inViewControllerWithID:STORAGE_PANE_ID];
        }
        if (previousCard == CT_MockingboardC) {
            [self performSelector:@selector(updateMockingboardPreferences) inViewControllerWithID:AUDIO_VIDEO_PANE_ID];
        }
        self.computerRebootEmulatorButton.enabled = [theAppDelegate emulationHardwareChanged];
        
        [self configureSlots];
    }
}

- (IBAction)slotMoreAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSButton class]]) {
        NSButton *moreButton = (NSButton *)sender;
        const UINT slot = (UINT)moreButton.tag;
        CardManager &cardManager = GetCardMgr();
        const SS_CARDTYPE type = cardManager.QuerySlot(slot);
        
        NSViewController *viewController = nil;
        NSPopoverBehavior behavior = NSPopoverBehaviorTransient;
        switch (type) {
            case CT_Disk2: {
                viewController = [self.storyboard instantiateControllerWithIdentifier:@"DiskIIPreferencesID"];
                
                NSAssert([viewController isKindOfClass:[DiskIIPreferencesViewController class]], @"");
                DiskIIPreferencesViewController *vc = (DiskIIPreferencesViewController *)viewController;
                [vc setCard:dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(slot))];
                break;
            }
            case CT_GenericHDD: {
                viewController = [self.storyboard instantiateControllerWithIdentifier:@"HardDiskPreferencesID"];
                
                NSAssert([viewController isKindOfClass:[HardDiskPreferencesViewController class]], @"");
                HardDiskPreferencesViewController *vc = (HardDiskPreferencesViewController *)viewController;
                [vc setCard:dynamic_cast<HarddiskInterfaceCard*>(cardManager.GetObj(slot))];
                behavior = NSPopoverBehaviorSemitransient;
                break;
            }
            case CT_MockingboardC: {
                viewController = [self.storyboard instantiateControllerWithIdentifier:@"MockingboardPreferencesID"];
                
                NSAssert([viewController isKindOfClass:[MockingboardPreferencesViewController class]], @"");
                MockingboardPreferencesViewController *vc = (MockingboardPreferencesViewController *)viewController;
                [vc setCard:dynamic_cast<MockingboardCard*>(cardManager.GetObj(slot))];
                break;
            }
            case CT_RamWorksIII: {
                viewController = [self.storyboard instantiateControllerWithIdentifier:@"RamWorksPreferencesID"];
                
                NSAssert([viewController isKindOfClass:[RamWorksPreferencesViewController class]], @"");
                break;
            }
            default:
                break;
        }
        
        if (viewController != nil) {
            NSPopover *popover = [[NSPopover alloc] init];
            popover.behavior = behavior;
            popover.contentViewController = viewController;
            [popover showRelativeToRect:moreButton.bounds ofView:moreButton preferredEdge:NSRectEdgeMaxX];
        }
    }
}

- (IBAction)expansionSlotAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    SetExpansionMemType((SS_CARDTYPE)self.computerExansionSlotButton.selectedTag);
    CreateLanguageCard();
    MemInitializeIO();
    
    self.computerRebootEmulatorButton.enabled = [theAppDelegate emulationHardwareChanged];
    
    [self configureSlots];
}

- (IBAction)expansionSlotMoreAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSViewController *viewController = nil;
    if ([sender isKindOfClass:[NSButton class]]) {
        NSButton *moreButton = (NSButton *)sender;
        
        switch (GetCurrentExpansionMemType()) {
            case CT_RamWorksIII: {
                viewController = [self.storyboard instantiateControllerWithIdentifier:@"RamWorksPreferencesID"];
                break;
            }
            default:
                break;
        }
        
        if (viewController != nil) {
            NSPopover *popover = [[NSPopover alloc] init];
            popover.behavior = NSPopoverBehaviorTransient;
            popover.contentViewController = viewController;
            [popover showRelativeToRect:moreButton.bounds ofView:moreButton preferredEdge:NSRectEdgeMaxX];
        }
    }
}

- (IBAction)pcapSlotAction:(id)sender {
#ifndef U2_USE_SLIRP
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([sender isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *slotButton = (NSPopUpButton *)sender;
        const std::string newInterface([slotButton.selectedItem.title cStringUsingEncoding:NSUTF8StringEncoding]);

        PCapBackend::SetRegistryInterface(SLOT3, newInterface);
    }
    
    self.computerRebootEmulatorButton.enabled = [theAppDelegate emulationHardwareChanged];
#endif // U2_USE_SLIRP
}

- (IBAction)copyProtectionDongleAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([sender isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *dongleButton = (NSPopUpButton *)sender;
        DONGLETYPE selectedDongleType = (DONGLETYPE)dongleButton.indexOfSelectedItem;
        SetCopyProtectionDongleType(selectedDongleType);
        RegSetConfigGameIOConnectorNewDongleType(GAME_IO_CONNECTOR, selectedDongleType);
    }
}

- (IBAction)rebootEmulatorAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.computerRebootEmulatorButton.enabled = NO;
    [theAppDelegate rebootEmulatorAction:sender];
}

- (IBAction)toggle50PercentScanLines:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.video50PercentScanLinesButton.state == NSControlStateValueOn) {
        [self setVideoStyle:VS_HALF_SCANLINES enabled:YES];
        NSLog(@"Enable 50%% scan lines");
    }
    else {
        [self setVideoStyle:VS_HALF_SCANLINES enabled:NO];
        NSLog(@"Disable 50%% scan lines");
    }
    [theAppDelegate applyVideoModeChange];
}

- (IBAction)customColorWellAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    Video &video = GetVideo();
    const int r = self.videoCustomColorWell.color.redComponent * 0xFF;
    const int g = self.videoCustomColorWell.color.greenComponent * 0xFF;
    const int b = self.videoCustomColorWell.color.blueComponent * 0xFF;
    video.SetMonochromeRGB(RGB(r, g, b));
    [theAppDelegate applyVideoModeChange];
    NSLog(@"Set custom monochrome color to #%02X%02X%02X", r, g, b);
}

- (IBAction)speakerVolumeSliderAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    const int volumeMax = GetPropertySheet().GetVolumeMax();
    const int volume = volumeMax - self.audioSpeakerVolumeSlider.intValue;
    SpkrSetVolume(volume, volumeMax);
    RegSaveValue(REG_CONFIG, REGVALUE_SPKR_VOLUME, true, volume);
    NSLog(@"Set speaker volume to %d", volume);
}

- (IBAction)mockingboardVolumeSliderAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    const int volumeMax = GetPropertySheet().GetVolumeMax();
    const int volume = volumeMax - self.audioMockingboardVolumeSlider.intValue;
    CardManager &cardManager = GetCardMgr();
    cardManager.GetMockingboardCardMgr().SetVolume(volume, volumeMax);
    NSLog(@"Set Mockingboard volume to %d", volume);
}

- (IBAction)diskAction:(id)sender {
    NSLog(@"%s (%ld)", __PRETTY_FUNCTION__, (long)[(NSView *)sender tag]);
}

- (IBAction)diskEjectAction:(id)sender {
    NSLog(@"%s (%ld)", __PRETTY_FUNCTION__, (long)[(NSView *)sender tag]);
}

- (IBAction)toggleDiskEnhancedSpeed:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    CardManager &cardManager = GetCardMgr();
    BOOL enhancedDisk = (self.storageEnhancedSpeedButton.state == NSControlStateValueOn);
    cardManager.GetDisk2CardMgr().SetEnhanceDisk(enhancedDisk);
    RegSaveValue(REG_CONFIG, REGVALUE_ENHANCE_DISK_SPEED, true, enhancedDisk);
}

- (IBAction)hardDiskAddAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.canDownloadUbiquitousContents = YES;
    panel.message = NSLocalizedString(@"Select hard disk image", @"");
    panel.prompt = NSLocalizedString(@"Connect", @"");
    panel.delegate = self;

    if ([panel runModal] == NSModalResponseOK) {
        const char *fileSystemRepresentation = panel.URL.fileSystemRepresentation;
        std::string pathname(fileSystemRepresentation);
        HarddiskInterfaceCard *hddCard = [self hddCard];
        int hddIndex;
        if (self.storageHardDiskTableView.selectedRow >= 0) {
            hddIndex = (int)self.storageHardDiskTableView.selectedRow;
            NSAssert(hddIndex >= HARDDISK_1 && hddIndex < NUM_HARDDISKS, @"selection was out of range");
        }
        else {
            // find the first empty slot
            for (hddIndex = 0; hddIndex < NUM_HARDDISKS; hddIndex++) {
                if (hddCard->HarddiskGetFullPathName(hddIndex).empty()) {
                    break;
                }
            }
            NSAssert(hddIndex < NUM_HARDDISKS, @"add button should not have been enabled");
        }
        if (hddCard->Insert(hddIndex, pathname)) {
            NSLog(@"Loaded '%s' as HDD %d", fileSystemRepresentation, hddIndex);
            [self performSelector:@selector(updateHardDiskPreferences) inViewControllerWithID:STORAGE_PANE_ID];
            [theAppDelegate reconfigureDrives];
        }
        else {
            NSLog(@"Failed to '%s' as HDD", fileSystemRepresentation);
        }
    }
}

- (IBAction)hardDiskDeleteAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (self.storageHardDiskTableView.selectedRow >= 0) {
        int hddIndex = (int)self.storageHardDiskTableView.selectedRow;
        HarddiskInterfaceCard *hddCard = [self hddCard];
        NSAssert(hddIndex >= HARDDISK_1 && hddIndex < NUM_HARDDISKS, @"selection was out of range");
        NSAssert(!hddCard->HarddiskGetFullPathName(hddIndex).empty(), @"delete sent to empty slot");
        hddCard->Unplug(hddIndex);
        [self performSelector:@selector(updateHardDiskPreferences) inViewControllerWithID:STORAGE_PANE_ID];
        [theAppDelegate reconfigureDrives];
    }
}

- (IBAction)createHardDiskAction:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    self.diskMakerWC = [[DiskMakerWindowController alloc] init];
    [self.diskMakerWC selectHardDisk];
    [self.diskMakerWC showWindow:self];
}

- (IBAction)gameControllerAction:(id)sender {
    UserDefaults *defaults = [UserDefaults sharedInstance];
    if (self.gameController.selectedItem == self.gameController.itemArray[0]) {
        defaults.gameController = GameControllerNone;
        self.gameControllerJoystick.enabled = NO;
        self.gameControllerButton0.enabled = NO;
        self.gameControllerButton1.enabled = NO;
    }
    else if (self.gameController.selectedItem == self.gameController.lastItem) {
        defaults.gameController = GameControllerNumericKeypad;
        self.gameControllerJoystick.enabled = NO;
        self.gameControllerButton0.enabled = NO;
        self.gameControllerButton1.enabled = NO;
    }
    else {
        defaults.gameController = self.gameController.titleOfSelectedItem;
        self.gameControllerJoystick.enabled = YES;
        self.gameControllerButton0.enabled = YES;
        self.gameControllerButton1.enabled = YES;
    }
}

- (IBAction)mapJoystickAction:(id)sender {
    UserDefaults *defaults = [UserDefaults sharedInstance];
    defaults.joystickMapping = self.gameControllerJoystick.indexOfSelectedItem;
}

- (IBAction)mapJoystickButton0Action:(id)sender {
    UserDefaults *defaults = [UserDefaults sharedInstance];
    defaults.joystickButton0Mapping = self.gameControllerButton0.indexOfSelectedItem;
}

- (IBAction)mapJoystickButton1Action:(id)sender {
    UserDefaults *defaults = [UserDefaults sharedInstance];
    defaults.joystickButton1Mapping = self.gameControllerButton1.indexOfSelectedItem;
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    // we have several NSOpenPanels in this class but luckily the others are
    // directory pickers so don't need a delegate yet, so we don't have to
    // disambiguate.
    
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
    
    return [@[ @"PO", @"HDV" ] containsObject:url.pathExtension.uppercaseString];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return NUM_HARDDISKS;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result = [tableView makeViewWithIdentifier:@"HardDiskTableCellView" owner:self];
    HarddiskInterfaceCard *hddCard = [self hddCard];
    if (hddCard != nil) {
        NSString *hddImagePath = [NSString stringWithUTF8String:hddCard->HarddiskGetFullPathName((int)row).c_str()];
        if (hddImagePath.length == 0) {
            hddImagePath = NSLocalizedString(@"—", @"empty slot");
        }
        result.textField.stringValue = hddImagePath;
    }
    else {
        result.textField.stringValue = NSLocalizedString(@"—", @"empty slot");
    }
    return result;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = (NSTableView *)notification.object;
    HarddiskInterfaceCard *hddCard = [self hddCard];
    // always enable "+" button to add image to empty slot or replace image in filled slot
    self.storageHardDiskAddButton.enabled = YES;
    // enable "-" button if slot is filled
    self.storageHardDiskDeleteButton.enabled = !hddCard->HarddiskGetFullPathName((int)tableView.selectedRow).empty();
}

#pragma mark - Utilities

- (NSDictionary *)localizedComputerNameMap {
    // helps map eApple2Type to a readable string
    return @{
        @(A2TYPE_APPLE2):           NSLocalizedString(@"Apple ][ Emulator", @""),
        @(A2TYPE_APPLE2PLUS):       NSLocalizedString(@"Apple ][+ Emulator", @""),
        @(A2TYPE_APPLE2JPLUS):      NSLocalizedString(@"Apple ][ J-Plus Emulator", @""),
        @(A2TYPE_APPLE2E):          NSLocalizedString(@"Apple //e Emulator", @""),
        @(A2TYPE_APPLE2EENHANCED):  NSLocalizedString(@"Enhanced Apple //e Emulator", @""),
        @(A2TYPE_APPLE2C):          NSLocalizedString(@"Apple //c Emulator", @""),
        @(A2TYPE_PRAVETS82):        NSLocalizedString(@"Pravets 82 Emulator", @""),
        @(A2TYPE_PRAVETS8M):        NSLocalizedString(@"Pravets 8M Emulator", @""),
        @(A2TYPE_PRAVETS8A):        NSLocalizedString(@"Pravets 8A Emulator", @""),
        @(A2TYPE_TK30002E):         NSLocalizedString(@"TK3000 //e Emulator", @""),
        @(A2TYPE_BASE64A):          NSLocalizedString(@"Base64A Emulator", @""),
    };
}

- (NSArray *)slotButtonsArray {
    // so that we can index computerSlotButtons by SLOT0..SLOT7
    return @[
        self.computerSlot0Button,
        self.computerSlot1Button,
        self.computerSlot2Button,
        self.computerSlot3Button,
        self.computerSlot4Button,
        self.computerSlot5Button,
        self.computerSlot6Button,
        self.computerSlot7Button,
    ];
}

- (NSArray *)slotMoreButtonsArray {
    // so that we can index computerSlotMoreButtons by SLOT0..SLOT7
    return @[
        self.computerSlot0MoreButton,
        self.computerSlot1MoreButton,
        self.computerSlot2MoreButton,
        self.computerSlot3MoreButton,
        self.computerSlot4MoreButton,
        self.computerSlot5MoreButton,
        self.computerSlot6MoreButton,
        self.computerSlot7MoreButton,
    ];
}

+ (NSDictionary *)localizedCardNameMap {
    // helps map SS_CARDTYPE to a readable string
    return @{
        @(CT_Empty):                NSLocalizedString(@"—", @"empty slot"),
        @(CT_Disk2):                NSLocalizedString(@"Apple Disk II", @""),
        @(CT_SSC):                  NSLocalizedString(@"Apple Super Serial Card", @""),
        @(CT_MockingboardC):        NSLocalizedString(@"Mockingboard C (sound)", @""),
        @(CT_GenericPrinter):       NSLocalizedString(@"Generic Printer", @""),
        @(CT_GenericHDD):           NSLocalizedString(@"Hard Disk Controller", @""),
        @(CT_GenericClock):         NSLocalizedString(@"Generic Clock", @""),
        @(CT_MouseInterface):       NSLocalizedString(@"Mouse Interface", @""),
        @(CT_Z80):                  NSLocalizedString(@"Z-80 SoftCard", @""),
        @(CT_Phasor):               NSLocalizedString(@"Phasor (sound)", @""),
        @(CT_Echo):                 NSLocalizedString(@"Echo (speech)", @""),
        @(CT_SAM):                  NSLocalizedString(@"Software Automatic Mouth (speech)", @""),
        @(CT_80Col):                NSLocalizedString(@"80-column text card (1K)", @""),
        @(CT_Extended80Col):        NSLocalizedString(@"Extended 80-column text card (64K)", @""),
        @(CT_RamWorksIII):          NSLocalizedString(@"RamWorks III (up to 16MB)", @""),
        @(CT_Uthernet):             NSLocalizedString(@"Uthernet I (network)", @""),
        @(CT_LanguageCard):         NSLocalizedString(@"Apple Language Card", @""),
        @(CT_LanguageCardIIe):      NSLocalizedString(@"Apple Language Card //e", @""),
        @(CT_Saturn128K):           NSLocalizedString(@"Saturn 128K (memory)", @""),
        @(CT_FourPlay):             NSLocalizedString(@"4play (joystick)", @""),
        @(CT_SNESMAX):              NSLocalizedString(@"SNES MAX (game controller)", @""),
        @(CT_VidHD):                NSLocalizedString(@"VidHD (video)", @""),
        @(CT_Uthernet2):            NSLocalizedString(@"Uthernet II (network)", @""),
        @(CT_MegaAudio):            NSLocalizedString(@"MEGA Audio", @""),
        @(CT_SDMusic):              NSLocalizedString(@"SD Music (sound)", @""),
    };
}

+ (NSDictionary *)localizedCopyProtectionDongleNameMap {
    // helps map DONGLETYPE to a readable string
    return @{
        @(DT_EMPTY):                NSLocalizedString(@"—", @"empty slot"),
        @(DT_SDSSPEEDSTAR):         NSLocalizedString(@"SDS DataKey - SpeedStar", @"Protection dongle for Southwestern Data Systems 'SpeedStar' Applesoft Compiler"),
        @(DT_CODEWRITER):           NSLocalizedString(@"Cortechs Corp - CodeWriter", @"Protection key for Dynatech Microsoftware / Cortechs Corp 'CodeWriter'"),
        @(DT_ROBOCOM500):           NSLocalizedString(@"Robocom Ltd - Robo 500", @"Interface Module for Robocom Ltd's Robo 500"),
        @(DT_ROBOCOM1000):          NSLocalizedString(@"Robocom Ltd - Robo 1000", @"Interface Module for Robocom Ltd's Robo 1000"),
        @(DT_ROBOCOM1500):          NSLocalizedString(@"Robocom Ltd - Robo 1500", @"Interface Module for Robocom Ltd's Robo 1500"),
        @(DT_HAYDENCOMPILER):       NSLocalizedString(@"Hayden - Applesoft Compiler", @"Protection key for Hayden Book Company, Inc's Applesoft Compiler (1981)"),
    };
}

// FIXME replace when https://github.com/AppleWin/AppleWin/issues/1488 is fixed
- (BOOL)cardTypeHasOptions:(SS_CARDTYPE)cardType {
    // must match CPageSlots::CardTypeHasOptions()
    switch (cardType) {
    case CT_Disk2: // fallthrough
    case CT_GenericHDD: // fallthrough
    case CT_SSC: // fallthrough
    case CT_GenericPrinter: // fallthrough
    case CT_MockingboardC: // fallthrough
    case CT_MouseInterface: // fallthrough
    case CT_Phasor: // fallthrough
    case CT_Saturn128K: // fallthrough
    case CT_Uthernet: // fallthrough
    case CT_Uthernet2: // fallthrough
    case CT_RamWorksIII: // fallthrough
        return YES;
    default:
        return NO;
    }
}

- (NSColor *)colorWithColorRef:(DWORD)colorRef {
    // reverse of RGB()
    return [NSColor colorWithRed:(colorRef & 0xFF) / 255.0
                           green:((colorRef >> 8) & 0xFF) / 255.0
                            blue:((colorRef >> 16) & 0xFF) / 255.0
                           alpha:1];
}

- (void)setVideoStyle:(VideoStyle_e)style enabled:(BOOL)enabled {
    Video &video = GetVideo();
    VideoStyle_e currentVideoStyle = video.GetVideoStyle();
    if (enabled) {
        currentVideoStyle = VideoStyle_e(currentVideoStyle | style);
    }
    else {
        currentVideoStyle = VideoStyle_e(currentVideoStyle & (~style));
    }
    video.SetVideoStyle(currentVideoStyle);
}

- (HarddiskInterfaceCard *)hddCard {
    CardManager &cardManager = GetCardMgr();
    
    // Hard disk
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        if (cardManager.QuerySlot(slot) == CT_GenericHDD) {
            return dynamic_cast<HarddiskInterfaceCard *>(cardManager.GetObj(slot));
        }
    }
    return nil;
}

- (BOOL)isMockingboardInstalled {
    CardManager &cardManager = GetCardMgr();
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        if (cardManager.QuerySlot(slot) == CT_MockingboardC) {
            return YES;
        }
    }
    return NO;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
// this should be okay because we're only calling methods returning void
- (void)performSelector:(SEL)selector inViewControllerWithID:(NSString *)vcID {
    if ([[self valueForKey:@"vcId"] isEqualToString:vcID]) {
        [self performSelector:selector];
        return;
    }
    
    // forward to the right view contoller instead
    for (PreferencesViewController *vc in self.parentViewController.childViewControllers) {
        if ([[vc valueForKey:@"vcId"] isEqualToString:vcID]) {
            [vc performSelector:selector];
            return;
        }
    }
}
#pragma clang diagnostic pop

@end
