//
//  DebuggerWindowController.h
//  Mariani
//
//  Created by sh95014 on 5/29/23.
//

#import <Cocoa/Cocoa.h>
#import "EmulatorViewController.h"
#import "DisassemblyTableViewController.h"
#import "InspectorOutlineViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DebuggerWindowController : NSWindowController
    <NSTabViewDelegate, NSSplitViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate, NSControlTextEditingDelegate,
    DisassemblyTableViewControllerDelegate, InspectorOutlineViewControllerDelegate>

- (id)initWithEmulatorVC:(EmulatorViewController *)emulatorVC;

@end

NS_ASSUME_NONNULL_END
