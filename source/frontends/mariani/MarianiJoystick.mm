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
    GCController *gc = [GCController defaultController];
    GCExtendedGamepad *gamepad = [gc extendedGamepad];
    
    if (gamepad != nil) {
        GCControllerDirectionPad *directionPad = thumbstick(gamepad);
        switch (i) {
            case 0:  return directionPad.xAxis.value;
            case 1:  return -directionPad.yAxis.value;
        }
    }
    return 0;
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

}
