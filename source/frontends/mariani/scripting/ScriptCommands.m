//
//  ScriptCommands.m
//  Mariani
//
//  Created by sh95014 on 8/25/23.
//

#import "ScriptCommands.h"
#import "AppDelegate.h"

@implementation RebootCommand

- (id)performDefaultImplementation {
    [theAppDelegate rebootEmulatorAction:self];
    return nil;
}

@end
