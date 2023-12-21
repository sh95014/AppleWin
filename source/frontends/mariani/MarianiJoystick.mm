//
//  MarianiJoystick.mm
//  Mariani
//
//  Created by sh95014 on 2/10/22.
//

#import "MarianiJoystick.h"
#import "AppDelegate.h"
#import "UserDefaults.h"
#import <GameController/GameController.h>

#define PDL_CENTER          0

namespace mariani
{

bool Gamepad::getButton(int i) const
{
    GCController *gc = [GCController defaultController];
    GCExtendedGamepad *gamepad = [gc extendedGamepad];
    GCControllerButtonInput *button = inputForButton(gamepad, i);
    return (button != nil) ? button.isPressed : 0;
}

double Gamepad::getAxis(int i) const
{
    UserDefaults *defaults = [UserDefaults sharedInstance];
    if ([defaults.gameController isEqualToString:GameControllerNumericKeypad]) {
        double negativeVector = 0;
        double neutralVector = 0;
        double positiveVector = 0;
        switch (i) {
            case 0:
                negativeVector = int(keysDown.count('1') + keysDown.count('4') + keysDown.count('7'));
                neutralVector =  int(keysDown.count('2')                       + keysDown.count('8'));
                positiveVector = int(keysDown.count('3') + keysDown.count('6') + keysDown.count('9'));
                break;
            case 1:
                negativeVector = int(keysDown.count('7') + keysDown.count('8') + keysDown.count('9'));
                neutralVector =  int(keysDown.count('4')                       + keysDown.count('6'));
                positiveVector = int(keysDown.count('1') + keysDown.count('2') + keysDown.count('3'));
                break;
        }
        if (positiveVector + neutralVector + negativeVector < 0.01) {
            // avoid division by 0
            return PDL_CENTER;
        }
        return (positiveVector - negativeVector) / (positiveVector + neutralVector + negativeVector);
    }
    else {
        GCController *gc = [GCController defaultController];
        GCExtendedGamepad *gamepad = [gc extendedGamepad];
        
        if (gamepad != nil) {
            GCControllerDirectionPad *directionPad = thumbstick(gamepad);
            switch (i) {
                case 0:  return directionPad.xAxis.value;
                case 1:  return -directionPad.yAxis.value;
            }
        }
    }
    return PDL_CENTER;
}

GCControllerButtonInput *Gamepad::inputForButton(GCExtendedGamepad *gamepad, int i) const
{
    if (gamepad != NULL) {
        UserDefaults *defaults = [UserDefaults sharedInstance];
        NSInteger button = (i == 0) ? defaults.joystickButton0Mapping : defaults.joystickButton1Mapping;
        
        // must match joystickButtonOptions in UserDefaults
        switch (button) {
            case 0:  return gamepad.buttonA;
            case 1:  return gamepad.buttonB;
            case 2:  return gamepad.buttonX;
            case 3:  return gamepad.buttonY;
            case 4:  return gamepad.leftTrigger;
            case 5:  return gamepad.rightTrigger;
            case 6:  return gamepad.leftShoulder;
            case 7:  return gamepad.rightShoulder;
            case 8:  return gamepad.leftThumbstickButton;
            case 9:  return gamepad.rightThumbstickButton;
        }
    }
    return NULL;
}

GCControllerDirectionPad *Gamepad::thumbstick(GCExtendedGamepad *gamepad) const
{
    if (gamepad != NULL) {
        UserDefaults *defaults = [UserDefaults sharedInstance];
        
        // must match joystickOptions in UserDefaults
        switch (defaults.joystickMapping) {
            case 0:  return gamepad.leftThumbstick;
            case 1:  return gamepad.rightThumbstick;
        }
    }
    return NULL;
}

void Gamepad::numericKeyDown(char key) {
    if (key == '0') {
        setButtonPressed(ourSolidApple);
    }
    else {
        keysDown.insert(key);
    }
}

void Gamepad::numericKeyUp(char key) {
    if (key == '0') {
        setButtonReleased(ourSolidApple);
    }
    else {
        keysDown.erase(key);
    }
}

}
