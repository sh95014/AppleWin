//
//  PreferencesWindowController.m
//  Mariani
//
//  Created by sh95014 on 12/30/21.
//

#import "PreferencesWindowController.h"
#import "AppDelegate.h"

@implementation PreferencesWindowController

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if ([theAppDelegate emulationHardwareChanged]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        alert.messageText = NSLocalizedString(@"Reboot Emulator", @"");
        alert.informativeText = NSLocalizedString(@"Changes to hardware configuration require the emulator to be rebooted to take effect.", @"");
        alert.alertStyle = NSAlertStyleWarning;
        alert.icon = [NSImage imageWithSystemSymbolName:@"power.circle" accessibilityDescription:@""];
        [alert addButtonWithTitle:NSLocalizedString(@"Reboot", @"")];
        [alert runModal];
        [theAppDelegate rebootEmulatorAction:sender];
    }
    
    // either way, just hide, don't actually close
    [self.window orderOut:sender];
    return NO;
}

@end
