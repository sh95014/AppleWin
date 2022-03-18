//
//  EmulatorViewController.h
//  Mariani
//
//  Copyright © 2021 Apple Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import <Cocoa/Cocoa.h>
#import "CommonTypes.h"
#import "EmulatorRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@protocol EmulatorViewControllerDelegate <NSObject>

- (BOOL)shouldPlayAudio;
- (void)terminateWithReason:(NSString *)reason;

- (void)screenRecordingDidStart;
- (void)screenRecordingDidTick;
- (void)screenRecordingDidTock;
- (void)screenRecordingDidStop;

- (void)printerWindowDidClose;

- (void)updateStatus:(NSString *)status;

- (NSURL *)unusedURLForFilename:(NSString *)desiredFilename extension:(NSString *)extension inFolder:(NSURL *)folder;

@end

@interface EmulatorViewController : NSViewController <NSWindowDelegate, EmulatorRendererDelegate>

@property (nullable, weak) id<EmulatorViewControllerDelegate> delegate;

- (void)start;
- (void)pause;
- (void)reboot;
- (void)reinitialize;
- (void)stop;

- (void)toggleScreenRecording;
- (void)saveScreenshot;

- (void)displayTypeDidChange;
- (void)videoModeDidChange;
- (BOOL)emulationHardwareChanged;

@end

NS_ASSUME_NONNULL_END
