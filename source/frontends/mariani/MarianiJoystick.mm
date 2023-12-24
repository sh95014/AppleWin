//
//  MarianiJoystick.mm
//  Mariani
//
//  Created by sh95014 on 2/10/22.
//

#import "MarianiJoystick.h"
#import "AppDelegate.h"
#import "UserDefaults.h"

#define PDL_CENTER          0

namespace mariani
{

Gamepad::Gamepad()
{
    updateController();
}

bool Gamepad::getButton(int i) const
{
    GCExtendedGamepad *gamepad = [controller extendedGamepad];
    GCControllerButtonInput *button = inputForButton(gamepad, i);
    return (button != nil) ? button.isPressed : 0;
}

double Gamepad::getAxis(int i) const
{
    if (controllerType == GCNumericKeypad) {
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
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        
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

void Gamepad::updateController()
{
    UserDefaults *defaults = [UserDefaults sharedInstance];
    NSString *fullName = defaults.gameController;
    if ([fullName isEqualToString:GameControllerNone]) {
        controllerType = GCNone;
        controller = NULL;
    }
    else if ([fullName isEqualToString:GameControllerNumericKeypad]) {
        controllerType = GCNumericKeypad;
        controller = NULL;
    }
    else {
        for (GCController *c in [GCController controllers]) {
            if ([c.fullName isEqualToString:fullName]) {
                controller = c;
                controllerType = GCGameController;
                break;
            }
        }
        // must match joystickOptions in UserDefaults
        thumbstickType = (defaults.joystickMapping == 1) ? GCRightThumbstick : GCLeftThumbstick;
        // must match joystickButtonOptions in UserDefaults
        buttonMappings[0] = defaults.joystickButton0Mapping;
        buttonMappings[1] = defaults.joystickButton1Mapping;
    }
}

GCControllerButtonInput *Gamepad::inputForButton(GCExtendedGamepad *gamepad, int i) const
{
    if (gamepad != NULL) {
        assert(i >= 0 && i <= 1);
        NSInteger button = buttonMappings[i];
        
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
        switch (thumbstickType) {
            case GCLeftThumbstick:   return gamepad.leftThumbstick;
            case GCRightThumbstick:  return gamepad.rightThumbstick;
        }
    }
    return NULL;
}

void Gamepad::numericKeyDown(char key)
{
    if (key == '0') {
        setButtonPressed(ourSolidApple);
    }
    else {
        keysDown.insert(key);
    }
}

void Gamepad::numericKeyUp(char key)
{
    if (key == '0') {
        setButtonReleased(ourSolidApple);
    }
    else {
        keysDown.erase(key);
    }
}

}
