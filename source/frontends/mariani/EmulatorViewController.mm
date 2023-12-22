//
//  EmulatorViewController.mm
//  Mariani
//

//  Parts of this code are derived from an Apple sample project, whose copyright
//  terms are replicated below:

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

#import "EmulatorViewController.h"
#import "EmulatorView.h"
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CMBlockBuffer.h>

#import "windows.h"

#import "context.h"

#import "benchmark.h"
#import "Core.h"
#import "fileregistry.h"
#import "programoptions.h"
#import "sdirectsound.h"

#import "CommonTypes.h"
#import "MarianiFrame.h"
#import "MarianiJoystick.h"
#import "EmulatorRenderer.h"
#import "Interface.h"
#import "UserDefaults.h"

#define SCREEN_RECORDING_FILE_NAME  NSLocalizedString(@"Mariani Recording", @"default name for new screen recording")
#define SCREENSHOT_FILE_NAME        NSLocalizedString(@"Mariani Screen Shot", @"default name for new screenshot")

// display emulated CPU speed in the status bar
#undef SHOW_EMULATED_CPU_SPEED

const NSNotificationName EmulatorDidEnterDebugModeNotification = @"EmulatorDidEnterDebugModeNotification";
const NSNotificationName EmulatorDidExitDebugModeNotification = @"EmulatorDidExitDebugModeNotification";
const NSNotificationName EmulatorDidRebootNotification = @"EmulatorDidRebootNotification";
const NSNotificationName EmulatorDidChangeDisplayNotification = @"EmulatorDidChangeDisplayNotification";

@interface AudioOutput : NSObject
@property (assign) UInt32 channels;
@property (assign) UInt32 sampleRate;
@property (retain) AVAssetWriterInput *writerInput;
@property (retain) NSMutableData *data;
@end

@implementation AudioOutput
@end

@interface EmulatorViewController ()

@property (strong) EmulatorRenderer *renderer;

@property RegistryContext *registryContext;
@property Initialisation *initialisation;

#ifdef SHOW_EMULATED_CPU_SPEED
@property NSDate *samplePeriodBeginClockTime;
@property uint64_t samplePeriodBeginCumulativeCycles;
@property NSInteger frameCount;
#endif // SHOW_EMULATED_CPU_SPEED
@property NSTimer *runLoopTimer;
@property CVDisplayLinkRef displayLink;

@property AVAssetWriter *videoWriter;
@property AVAssetWriterInput *videoWriterInput;
@property AVAssetWriterInputPixelBufferAdaptor *videoWriterAdaptor;
@property int64_t videoWriterFrameNumber;
@property NSTimer *recordingTimer;

@property NSMutableArray<AudioOutput *> *audioOutputs;

@property AppMode_e savedAppMode;

@end

// Don't want to pollute ObjC headers with C++ or create a new one just for this,
// but this needs to match the definition in main.mm.
extern common2::EmulatorOptions gEmulatorOptions;

@implementation EmulatorViewController {
    EmulatorView *_view;
    FrameBuffer frameBuffer;
    std::shared_ptr<mariani::Gamepad> gamepad;
}

std::shared_ptr<mariani::MarianiFrame> frame;

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.audioOutputs = [NSMutableArray array];
    
    self.registryContext = new RegistryContext(CreateFileRegistry(gEmulatorOptions));
    frame.reset(new mariani::MarianiFrame(gEmulatorOptions));
    gamepad.reset(new mariani::Gamepad());
    self.initialisation = new Initialisation(frame, gamepad);
    applyOptions(gEmulatorOptions);
    frame->Begin();
    self.savedAppMode = g_nAppMode;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self rebuildView:NO];
}

- (void)rebuildView:(BOOL)notify {
    _view = (EmulatorView *)self.view;
    _view.enableSetNeedsDisplay = NO;
    _view.device = MTLCreateSystemDefaultDevice();
    _view.numericKeyDelegate = self;
#ifdef DEBUG
    //  useful for debugging quad sizing issues.
    _view.clearColor = MTLClearColorMake(0.0, 0.15, 0.3, 0.3);
#endif
    
    Video &video = GetVideo();
    frameBuffer.borderWidth = video.GetFrameBufferBorderWidth();
    frameBuffer.borderHeight = video.GetFrameBufferBorderHeight();
    frameBuffer.bufferWidth = video.GetFrameBufferWidth();
    frameBuffer.bufferHeight = video.GetFrameBufferHeight();
    frameBuffer.pixelWidth = video.GetFrameBufferBorderlessWidth();
    frameBuffer.pixelHeight = video.GetFrameBufferBorderlessHeight();
    
    _renderer = [[EmulatorRenderer alloc] initWithMetalKitView:_view frameBuffer:&frameBuffer];
    if (self.renderer == nil) {
        NSLog(@"Renderer initialization failed");
        return;
    }
    self.renderer.delegate = self;
    
    // Initialize the renderer with the view size.
    [self.renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];
    _view.delegate = self.renderer;
    
    [self.renderer createTexture];
    
    if (notify) {
        [[NSNotificationCenter defaultCenter] postNotificationName:EmulatorDidChangeDisplayNotification object:self];
    }
}

- (void)start {
#ifdef SHOW_EMULATED_CPU_SPEED
    // reset the effective CPU clock speed meters
    self.samplePeriodBeginClockTime = [NSDate now];
    self.samplePeriodBeginCumulativeCycles = g_nCumulativeCycles;
    self.frameCount = 0;
#endif // SHOW_EMULATED_CPU_SPEED
    
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(self.displayLink, &MyDisplayLinkCallback, (__bridge void *)self);
    CGDirectDisplayID viewDisplayID =
        (CGDirectDisplayID) [self.view.window.screen.deviceDescription[@"NSScreenNumber"] unsignedIntegerValue];
    CVDisplayLinkSetCurrentCGDisplay(_displayLink, viewDisplayID);
    CVDisplayLinkStart(self.displayLink);
    
    self.runLoopTimer = [NSTimer timerWithTimeInterval:0 target:self selector:@selector(runLoopTimerFired) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.runLoopTimer forMode:NSRunLoopCommonModes];
}

static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now, const CVTimeStamp *outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void *displayLinkContext)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        EmulatorViewController *emulatorVC = (__bridge EmulatorViewController *)displayLinkContext;
        emulatorVC->frameBuffer.data = frame->FrameBufferData();
        [[emulatorVC renderer] updateTextureWithData:emulatorVC->frameBuffer.data];
    });
    return kCVReturnSuccess;
}

- (void)runLoopTimerFired {
    // g_nAppMode can change through a debugger CLI command, so we notice it and notify others
    if (self.savedAppMode != g_nAppMode) {
        if ((self.savedAppMode == MODE_RUNNING || self.savedAppMode == MODE_STEPPING) && g_nAppMode == MODE_DEBUG) {
            [[NSNotificationCenter defaultCenter] postNotificationName:EmulatorDidEnterDebugModeNotification object:self];
        }
        if (self.savedAppMode == MODE_DEBUG && (g_nAppMode == MODE_RUNNING || g_nAppMode == MODE_STEPPING)) {
            [[NSNotificationCenter defaultCenter] postNotificationName:EmulatorDidExitDebugModeNotification object:self];
        }
        self.savedAppMode = g_nAppMode;
    }
    
#ifdef DEBUG
    NSDate *start = [NSDate now];
#endif
    
    frame->ExecuteOneFrame(1000000.0 / TARGET_FPS);

#ifdef SHOW_EMULATED_CPU_SPEED
    self.frameCount++;
    static uint64_t timeOfLastUpdate = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    uint64_t currentTime = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    if (currentTime - timeOfLastUpdate > 1000000000.0 / TARGET_FPS) {
        NSArray *cpus = @[ @"", @"6502", @"65C02", @"Z80" ];
        double clockSpeed =
            (double)(g_nCumulativeCycles - self.samplePeriodBeginCumulativeCycles) /
            -[self.samplePeriodBeginClockTime timeIntervalSinceNow];
        [self.delegate updateStatus:[NSString stringWithFormat:@"%@@%.3f MHz", cpus[GetActiveCpu()], clockSpeed / 1000000]];

        self.samplePeriodBeginClockTime = [NSDate now];
        self.samplePeriodBeginCumulativeCycles = g_nCumulativeCycles;
        self.frameCount = 0;
        timeOfLastUpdate = currentTime;
    }
#endif // SHOW_EMULATED_CPU_SPEED
    
#ifdef DEBUG
    NSTimeInterval duration = -[start timeIntervalSinceNow];
    if (duration > 1.0 / TARGET_FPS) {
        // oops, took too long
        NSLog(@"Frame time exceeded: %f ms", duration * 1000);
    }
#endif // DEBUG
}

- (void)recordingTimerFired {
    frameBuffer.data = frame->FrameBufferData();
    
    if (self.videoWriterInput.readyForMoreMediaData) {
        if (!self.isRecordingScreen) {
            self.recordingScreen = YES;
        }
        
        // make a CVPixelBuffer and point the frame buffer to it
        CVPixelBufferRef pixelBuffer = NULL;
        CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                                       frameBuffer.bufferWidth,
                                                       frameBuffer.bufferHeight,
                                                       kCVPixelFormatType_32BGRA,
                                                       frameBuffer.data,
                                                       frameBuffer.bufferWidth * 4,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       &pixelBuffer);
        if (status == kCVReturnSuccess && pixelBuffer != NULL) {
            // append the CVPixelBuffer into the output stream
            [self.videoWriterAdaptor appendPixelBuffer:pixelBuffer
                                  withPresentationTime:CMTimeMake(self.videoWriterFrameNumber * (CMTIME_BASE / TARGET_FPS), CMTIME_BASE)];
            CVPixelBufferRelease(pixelBuffer);
            
            // if we realize that we've skipped a frame (i.e., videoWriter is
            // not nil but readyForMoreMediaData is false) should we also
            // increment videoWriterFrameNumber?
            self.videoWriterFrameNumber++;
        }
    }
    
    for (AudioOutput *audioOutput in self.audioOutputs) {
        if (audioOutput.writerInput.readyForMoreMediaData && audioOutput.data.length > 0) {
            const UInt32 bytesPerFrame = audioOutput.channels * sizeof(UInt16);
            const UInt32 frames = (UInt32)audioOutput.data.length / bytesPerFrame;
            const UInt32 blockSize = frames * bytesPerFrame;
            
            CMBlockBufferRef blockBuffer = NULL;
            OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                                 NULL,
                                                                 blockSize,
                                                                 NULL,
                                                                 NULL,
                                                                 0,
                                                                 blockSize,
                                                                 0,
                                                                 &blockBuffer);
            if (status != kCMBlockBufferNoErr) {
                NSLog(@"failed CMBlockBufferCreateWithMemoryBlock");
                continue;
            }
            
            status = CMBlockBufferReplaceDataBytes(audioOutput.data.bytes,
                                                   blockBuffer,
                                                   0,
                                                   blockSize);
            if (status != kCMBlockBufferNoErr) {
                NSLog(@"failed CMBlockBufferReplaceDataBytes");
                if (blockBuffer) { CFRelease(blockBuffer); }
                continue;
            }
            
            AudioStreamBasicDescription asbd = { 0 };
            asbd.mFormatID         = kAudioFormatLinearPCM;
            asbd.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
            asbd.mSampleRate       = audioOutput.sampleRate;
            asbd.mChannelsPerFrame = audioOutput.channels;
            asbd.mBitsPerChannel   = sizeof(SInt16) * CHAR_BIT;
            asbd.mFramesPerPacket  = 1;  // uncompressed audio
            asbd.mBytesPerFrame    = bytesPerFrame;
            asbd.mBytesPerPacket   = bytesPerFrame;
            
            CMFormatDescriptionRef format = NULL;
            status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                                                    &asbd,
                                                    0,
                                                    NULL,
                                                    0,
                                                    NULL,
                                                    NULL,
                                                    &format);
            if (status != noErr) {
                NSLog(@"failed CMAudioFormatDescriptionCreate");
                if (blockBuffer) { CFRelease(blockBuffer); }
                continue;
            }
            
            CMSampleBufferRef sampleBuffer = NULL;
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               blockBuffer,
                                               format,
                                               frames,
                                               0,
                                               NULL,
                                               0,
                                               NULL,
                                               &sampleBuffer);
            if (status != noErr) {
                NSLog(@"failed CMSampleBufferCreateReady");
                if (format) { CFRelease(format); }
                if (blockBuffer) { CFRelease(blockBuffer); }
                continue;
            }
            
            [audioOutput.writerInput appendSampleBuffer:sampleBuffer];
            
            // clean up
            if (sampleBuffer) { CFRelease(sampleBuffer); }
            if (format) { CFRelease(format); }
            if (blockBuffer) { CFRelease(blockBuffer); }
            audioOutput.data.length = 0;
        }
    }
    
    if (self.isRecordingScreen) {
        // blink the screen recording button
        if (self.videoWriterFrameNumber % TARGET_FPS == 0) {
            [self.delegate screenRecordingDidTick];
        }
        else if (self.videoWriterFrameNumber % TARGET_FPS == TARGET_FPS / 2) {
            [self.delegate screenRecordingDidTock];
        }
    }
}

- (void)pause {
    [self.runLoopTimer invalidate];
    CVDisplayLinkStop(self.displayLink);
    CVDisplayLinkRelease(self.displayLink);
    self.displayLink = NULL;
}

- (void)resetSpeed {
    frame->ResetSpeed();
}

- (void)reboot {
    frame->Restart();
    [[NSNotificationCenter defaultCenter] postNotificationName:EmulatorDidRebootNotification object:self];
}

- (void)reinitialize {
    frame->Destroy();
    frame->Initialize(true);
    [self rebuildView:YES];
}

- (void)enterDebugMode {
    frame->ChangeMode(MODE_DEBUG);
    self.savedAppMode = g_nAppMode;
    [[NSNotificationCenter defaultCenter] postNotificationName:EmulatorDidEnterDebugModeNotification object:self];
}

- (void)exitDebugMode {
    frame->ChangeMode(MODE_RUNNING);
    self.savedAppMode = g_nAppMode;
    [[NSNotificationCenter defaultCenter] postNotificationName:EmulatorDidExitDebugModeNotification object:self];
}

- (void)singleStep {
    frame->ChangeMode(MODE_DEBUG);
    frame->SingleStep();
}

- (void)stop {
    [self pause];
    if (frame != NULL) {
        frame->End();
    }
}

- (void)displayTypeDidChange {
    [self.renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];
}

- (void)videoModeDidChange {
    frame->ApplyVideoModeChange();
    
    // we need to recompute the overscan when video mode is changed
    [self displayTypeDidChange];
}

- (BOOL)emulationHardwareChanged {
    self.audioOutputs = [NSMutableArray array];
    return frame->HardwareChanged();
}

- (void)toggleScreenRecording {
    if (self.videoWriter == nil) {
        [self.delegate screenRecordingDidStart];
        NSURL *url = [self.delegate unusedURLForFilename:SCREEN_RECORDING_FILE_NAME
                                               extension:@"mov"
                                                inFolder:[[UserDefaults sharedInstance] recordingsFolder]];
        NSLog(@"Starting screen recording to %@", url);

        NSError *error = nil;
        self.videoWriter = [[AVAssetWriter alloc] initWithURL:url
                                                     fileType:AVFileTypeAppleM4V
                                                        error:&error];
        
        // set up the video writer input
        const NSInteger shouldOverscan = [self shouldOverscan];
        const NSInteger overscanWidth = shouldOverscan ? frameBuffer.borderWidth * OVERSCAN * 2 : 0;
        const NSInteger overscanHeight = shouldOverscan ? frameBuffer.borderHeight * OVERSCAN * 2 : 0;
        NSDictionary *videoSettings = @{
            AVVideoCodecKey: AVVideoCodecTypeHEVC,
            AVVideoWidthKey: @(frameBuffer.bufferWidth),
            AVVideoHeightKey: @(frameBuffer.bufferHeight),
            // just like the emulated display, overscan a little bit so that we
            // don't clip off portions of the pixels on the edge
            AVVideoCleanApertureKey: @{
                AVVideoCleanApertureWidthKey: @(frameBuffer.pixelWidth + overscanWidth),
                AVVideoCleanApertureHeightKey: @(frameBuffer.pixelHeight + overscanHeight),
                AVVideoCleanApertureHorizontalOffsetKey: @(0),
                AVVideoCleanApertureVerticalOffsetKey: @(0),
            },
        };
        self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                   outputSettings:videoSettings];
        self.videoWriterInput.transform = CGAffineTransformMakeScale(1, -1);
        self.videoWriterAdaptor =
            [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoWriterInput
                                                                             sourcePixelBufferAttributes:nil];
        [self.videoWriter addInput:self.videoWriterInput];
        
        // set up the audio writer inputs
        for (AudioOutput *audioOutput in self.audioOutputs) {
            AudioChannelLayout acl = { 0 };
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
            NSDictionary *audioSettings = @{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                AVSampleRateKey: @(44100),
                AVChannelLayoutKey: [NSData dataWithBytes:&acl length:sizeof(acl)],
            };
            audioOutput.writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                         outputSettings:audioSettings];
            audioOutput.writerInput.expectsMediaDataInRealTime = YES;
            [self.videoWriter addInput:audioOutput.writerInput];
        }
        
        [self.videoWriter startWriting];
        [self.videoWriter startSessionAtSourceTime:kCMTimeZero];
        self.videoWriterFrameNumber = 0;
        
        self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / TARGET_FPS) target:self selector:@selector(recordingTimerFired) userInfo:nil repeats:YES];
    }
    else {
        // stop recording
        NSLog(@"Ending screen recording");
        [self.recordingTimer invalidate];
        self.recordingScreen = NO;
        
        // mark the writer inputs as finished
        for (AudioOutput *audioOutput in self.audioOutputs) {
            [audioOutput.writerInput markAsFinished];
            audioOutput.writerInput = nil;
        }
        [self.videoWriterInput markAsFinished];
        
        [self.videoWriter finishWritingWithCompletionHandler:^(void) {
            if (self.videoWriter.status != AVAssetWriterStatusCompleted) {
                NSLog(@"Failed to write screen recording: %@", self.videoWriter.error);
            }
            
            // clean up
            self.videoWriter = nil;
            self.videoWriterInput = nil;
            self.videoWriterAdaptor = nil;
            self.videoWriterFrameNumber = 0;
            
            self.recordingScreen = NO;
            
            NSLog(@"Ended screen recording");
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self.delegate screenRecordingDidStop];
            });
        }];
    }
}

- (int)registerAudioOutputWithChannels:(UInt32)channels sampleRate:(UInt32)sampleRate {
    AudioOutput *audioOutput = [[AudioOutput alloc] init];
    audioOutput.channels = channels;
    audioOutput.sampleRate = sampleRate;
    audioOutput.data = [NSMutableData data];
    [self.audioOutputs addObject:audioOutput];
    return (int)(self.audioOutputs.count - 1);
}

- (void)submitOutput:(int)output audioData:(NSData *)data {
    if (self.isRecordingScreen) {
        if (output < self.audioOutputs.count) {
            [self.audioOutputs[output].data appendData:data];
        }
    }
}

- (void)takeScreenshotWithCompletion:(void (^)(NSData *pngData))completion {
#ifdef DEBUG
    NSDate *start = [NSDate now];
#endif
    
    // have the BMP screenshot written to a memory stream instead of a file...
    char *buffer;
    size_t bufferSize;
    FILE *memStream = open_memstream(&buffer, &bufferSize);
    GetVideo().Video_MakeScreenShot(memStream, Video::SCREENSHOT_560x384);
    fclose(memStream);

#ifdef DEBUG
    NSTimeInterval duration = -[start timeIntervalSinceNow];
    NSLog(@"Screenshot took: %f ms", duration * 1000);
#endif // DEBUG
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
#ifdef DEBUG
        NSDate *start = [NSDate now];
#endif
        // ...and then convert it to PNG for saving
        NSImage *image = [[NSImage alloc] initWithData:[NSData dataWithBytes:buffer length:bufferSize]];
        CGImageRef cgRef = [image CGImageForProposedRect:NULL context:nil hints:nil];
        NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
        [newRep setSize:[image size]];
        NSData *pngData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        free(buffer);
#ifdef DEBUG
        NSTimeInterval duration = -[start timeIntervalSinceNow];
        NSLog(@"Screenshot converted to PNG, PNG conversion took %f ms", duration * 1000);
#endif // DEBUG
        if (completion) {
            completion(pngData);
        }
    });
}

- (void)saveScreenshot:(BOOL)silent {
    [self takeScreenshotWithCompletion:^(NSData *pngData) {
        NSURL *url = [self.delegate unusedURLForFilename:SCREENSHOT_FILE_NAME
                                               extension:@"png"
                                                inFolder:[[UserDefaults sharedInstance] screenshotsFolder]];
        [pngData writeToURL:url atomically:YES];
        if (!silent) {
            [[NSSound soundNamed:@"Blow"] play];
        }
    }];
}

- (IBAction)copy:(id)sender {
    [self takeScreenshotWithCompletion:^(NSData *pngData) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard declareTypes:@[ NSPasteboardTypePNG ] owner:nil];
        if ([pasteboard setData:pngData forType:NSPasteboardTypePNG]) {
            NSLog(@"Sent to pasteboard: %@", pngData);
        }
    }];
}

- (IBAction)paste:(id)sender {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *string = [pasteboard stringForType:NSPasteboardTypeString];
    [self type:string];
}

- (void)type:(NSString *)string {
    [(EmulatorView *)self.view addStringToKeyboardBuffer:string];
}

#pragma mark - EmulatorRendererDelegate

- (BOOL)shouldOverscan {
    // the idealized display seems to show weird artifacts in the overscan
    // area, so we crop tightly
    Video &video = GetVideo();
    return (video.GetVideoType() != VT_COLOR_IDEALIZED);
}

#pragma mark - EmulatorViewDelegate

- (void)emulatorView:(EmulatorView *)view numericKeyDown:(unichar)key {
    gamepad->numericKeyDown(key);
}

- (void)emulatorView:(EmulatorView *)view numericKeyUp:(unichar)key {
    gamepad->numericKeyUp(key);
}

@end
