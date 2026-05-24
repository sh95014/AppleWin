//
//  AppDelegate.h
//  Mariani
//
//  Created by sh95014 on 12/27/21.
//

#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#import "EmulatorViewController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSOpenSavePanelDelegate, EmulatorViewControllerDelegate>

@property (strong) IBOutlet EmulatorViewController * _Nonnull emulatorVC;
@property (strong) NSProcessInfo * _Nonnull processInfo;
@property (atomic) NSInteger driveSwapCount;

- (void)applyVideoModeChange;
- (BOOL)emulationHardwareChanged;
- (IBAction)rebootEmulatorAction:(id _Nonnull)sender;
- (void)reconfigureDrives;
- (void)reinitializeFrame;
- (int)showModalAlertofType:(int)type withMessage:(NSString * _Nonnull)message information:(NSString *_Nonnull)information;
- (void)terminateWithReason:(NSString * _Nonnull)reason;
- (void)updateDriveLights;
- (void)setStatus:(nullable NSString *)status;
- (void)resetSpeed;

@end

#define theAppDelegate ((AppDelegate *)[[NSApplication sharedApplication] delegate])

#endif // __OBJC__

// for calling into AppDelegate from C++
void VideoRefresh(void);
int ShowModalAlertOfType(int type, const char * _Nonnull message, const char * _Nonnull information);
void UpdateDriveLights(void);
const char * _Nonnull PathToResourceNamed(const char * _Nonnull name);
const char * _Nonnull GetBuiltinSymbolsDirectory(void);
const char * _Nonnull GetSupportDirectory(void);

int RegisterAudioOutput(size_t channels, size_t sampleRate);
void SubmitAudio(int output, void * _Nonnull p1, size_t len1, void * _Nullable p2, size_t len2);
