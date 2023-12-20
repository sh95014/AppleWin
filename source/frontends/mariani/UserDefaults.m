//
//  UserDefaults.m
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#import "UserDefaults.h"
#import <GameController/GameController.h>

#define RECORDINGS_FOLDER_KEY           @"RecordingsFolder"
#define SCREENSHOTS_FOLDER_KEY          @"ScreenshotsFolder"
#define GAME_CONTROLLER_KEY             @"GameController"
#define JOYSTICK_MAPPING_KEY            @"JoystickMapping"
#define JOYSTICK_BUTTON0_MAPPING_KEY    @"JoystickButton0Mapping"
#define JOYSTICK_BUTTON1_MAPPING_KEY    @"JoystickButton1Mapping"

NSString *GameControllerNone = @"GameControllerNone";
NSString *GameControllerNumericKeypad = @"GameControllerNumericKeypad";

@implementation UserDefaults

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSURL *)recordingsFolder {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSURL *folder = [defaults URLForKey:RECORDINGS_FOLDER_KEY];
    if (folder == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
        folder = [NSURL fileURLWithPath:[paths objectAtIndex:0]];
    }
    return folder;
}

- (void)setRecordingsFolder:(NSURL *)recordingsFolder {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setURL:recordingsFolder forKey:RECORDINGS_FOLDER_KEY];
}

- (NSURL *)screenshotsFolder {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSURL *folder = [defaults URLForKey:SCREENSHOTS_FOLDER_KEY];
    if (folder == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
        folder = [NSURL fileURLWithPath:[paths objectAtIndex:0]];
    }
    return folder;
}

- (void)setScreenshotsFolder:(NSURL *)screenshotsFolder {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setURL:screenshotsFolder forKey:SCREENSHOTS_FOLDER_KEY];
}

- (NSString *)gameController {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *fullName = [defaults stringForKey:GAME_CONTROLLER_KEY];
    
    if ([fullName isEqualToString:GameControllerNone] ||
        [fullName isEqualToString:GameControllerNumericKeypad]) {
        return fullName;
    } else if (fullName.length > 0) {
        // make sure the selected controller is still conected
        for (GCController *controller in [GCController controllers]) {
            if ([controller.fullName isEqualToString:fullName]) {
                return fullName;
            }
        }
    }
    
    // fall back to current controller, if any
    GCController *current = [GCController current];
    if (current != nil) {
        return current.fullName;
    }
    
    return GameControllerNone;
}

- (void)setGameController:(NSString *)gameController {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:gameController forKey:GAME_CONTROLLER_KEY];
}

- (NSArray<NSString *> *)joystickOptions {
    return @[
        GCInputLeftThumbstick,
        GCInputRightThumbstick,
    ];
}

- (NSInteger)joystickMapping {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *value = [defaults valueForKey:JOYSTICK_MAPPING_KEY];
    if (value == nil) {
        return [self.joystickOptions indexOfObjectIdenticalTo:GCInputLeftThumbstick];
    }
    return [value integerValue];
}

- (void)setJoystickMapping:(NSInteger)joystickMapping {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:joystickMapping forKey:JOYSTICK_MAPPING_KEY];
}

- (NSArray<NSString *> *)joystickButtonOptions {
    return @[
        GCInputButtonA,
        GCInputButtonB,
        GCInputButtonX,
        GCInputButtonY,
        GCInputLeftTrigger,
        GCInputRightTrigger,
        GCInputLeftShoulder,
        GCInputRightShoulder,
    ];
}

- (NSInteger)joystickButton0Mapping {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *value = [defaults valueForKey:JOYSTICK_BUTTON0_MAPPING_KEY];
    if (value == nil) {
        return [self.joystickButtonOptions indexOfObjectIdenticalTo:GCInputButtonA];
    }
    return [value integerValue];
}

- (void)setJoystickButton0Mapping:(NSInteger)joystickButton0Mapping {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:joystickButton0Mapping forKey:JOYSTICK_BUTTON0_MAPPING_KEY];
}

- (NSInteger)joystickButton1Mapping {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *value = [defaults valueForKey:JOYSTICK_BUTTON1_MAPPING_KEY];
    if (value == nil) {
        return [self.joystickButtonOptions indexOfObjectIdenticalTo:GCInputButtonB];
    }
    return [value integerValue];
}

- (void)setJoystickButton1Mapping:(NSInteger)joystickButton0Mapping {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:joystickButton0Mapping forKey:JOYSTICK_BUTTON1_MAPPING_KEY];
}

@end

@implementation GCController (Mariani)

- (NSString *)fullName {
    return [NSString stringWithFormat:@"%@ %@", self.vendorName, self.productCategory];
}

+ (GCController *)controllerNamed:(NSString *)fullName {
    if (fullName != nil) {
        for (GCController *controller in [GCController controllers]) {
            if ([controller.fullName isEqualToString:fullName]) {
                return controller;
            }
        }
    }
    return nil;
}

+ (GCController *)defaultController {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *fullName = [defaults stringForKey:GAME_CONTROLLER_KEY];
    return [self controllerNamed:fullName];
}

@end
