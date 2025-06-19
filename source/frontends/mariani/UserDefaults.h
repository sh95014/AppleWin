//
//  UserDefaults.h
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *GameControllerNone;
extern NSString *GameControllerNumericKeypad;

@interface UserDefaults : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic) NSURL *recordingsFolder;
@property (nonatomic) NSURL *screenshotsFolder;
@property (nonatomic) BOOL mapDeleteKeyToLeftArrow;
@property (nonatomic) BOOL useLargeStatusBar;

@property (nonatomic) NSString *gameController;
@property (readonly) NSArray<NSString *> *joystickOptions;
@property (nonatomic) NSInteger joystickMapping;
@property (readonly) NSArray<NSString *> *joystickButtonOptions;
@property (nonatomic) NSInteger joystickButton0Mapping;
@property (nonatomic) NSInteger joystickButton1Mapping;

@end

@interface GCController (Mariani)

@property (readonly) NSString *fullName;

@end

NS_ASSUME_NONNULL_END
