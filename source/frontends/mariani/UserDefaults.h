//
//  UserDefaults.h
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UserDefaults : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic) NSURL *recordingsFolder;
@property (nonatomic) NSURL *screenshotsFolder;

@property (readonly) NSArray<NSString *> *joystickOptions;
@property (nonatomic) NSInteger joystickMapping;
@property (readonly) NSArray<NSString *> *joystickButtonOptions;
@property (nonatomic) NSInteger joystickButton0Mapping;
@property (nonatomic) NSInteger joystickButton1Mapping;

@end

NS_ASSUME_NONNULL_END
