//
//  MarianiJoystick.mm
//  Mariani
//
//  Created by sh95014 on 2/10/22.
//

#include "MarianiJoystick.h"
#include "AppDelegate.h"
#import <GameController/GameController.h>

namespace mariani
{

bool Gamepad::getButton(int i) const
{
    GCController *gc;
    if (@available(macOS 11.0, *)) {
        gc = [GCController current];
    }
    else {
        gc = GCController.controllers.firstObject;
    }
    GCExtendedGamepad *gamepad = [gc extendedGamepad];
    
    if (gamepad != nil) {
        switch (i) {
            case 0:  return gamepad.buttonA.isPressed;
            case 1:  return gamepad.buttonB.isPressed;
        }
    }
    return 0;
}

double Gamepad::getAxis(int i) const
{
    GCController *gc;
    if (@available(macOS 11.0, *)) {
        gc = [GCController current];
    }
    else {
        gc = GCController.controllers.firstObject;
    }
    GCExtendedGamepad *gamepad = [gc extendedGamepad];
    
    if (gamepad != nil) {
        switch (i) {
            case 0:  return gamepad.leftThumbstick.xAxis.value;
            case 1:  return -gamepad.leftThumbstick.yAxis.value;
        }
    }
    return 0;
}

}
