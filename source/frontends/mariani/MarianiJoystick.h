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
    bool getButton(int i) const override;
    double getAxis(int i) const override;

private:
    GCControllerButtonInput *inputForButton(GCExtendedGamepad *gamepad, int i) const;
    GCControllerDirectionPad *thumbstick(GCExtendedGamepad *gamepad) const;
};

}
