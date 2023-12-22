//
//  MarianiJoystick.h
//  Mariani
//
//  Created by sh95014 on 2/10/22.
//

#pragma once

#import "linux/paddle.h"
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

namespace mariani
{

class Gamepad : public Paddle
{
public:
    Gamepad();
    
    bool getButton(int i) const override;
    double getAxis(int i) const override;

    void numericKeyDown(char key);
    void numericKeyUp(char key);

    void updateController();

private:
    // remember the GameController mappings so we don't keep asking UserDefaults
    typedef enum {
        GCNone, GCNumericKeypad, GCGameController
    } ControllerType;
    ControllerType controllerType;
    GCController *controller;
    typedef enum {
        GCLeftThumbstick, GCRightThumbstick
    } ThumbstickType;
    ThumbstickType thumbstickType;
    NSInteger buttonMappings[2];
    
    GCControllerButtonInput *inputForButton(GCExtendedGamepad *gamepad, int i) const;
    GCControllerDirectionPad *thumbstick(GCExtendedGamepad *gamepad) const;

    std::set<char> keysDown;
};

}
