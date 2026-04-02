//
//  SlotPreferencesViewControllers.h
//  Mariani
//
//  Created by sh95014 on 4/2/26.
//

#import <AppKit/Appkit.h>

#include "StdAfx.h"
#import "Disk.h"
#import "Harddisk.h"
#import "Mockingboard.h"
#import "Memory.h"

@interface DiskIIPreferencesViewController : NSViewController
- (void)setCard:(Disk2InterfaceCard *)card;
@end

@interface HardDiskPreferencesViewController : NSViewController<NSTableViewDelegate, NSTableViewDataSource, NSOpenSavePanelDelegate>
- (void)setCard:(HarddiskInterfaceCard *)card;
@end

@interface MockingboardPreferencesViewController : NSViewController
- (void)setCard:(MockingboardCard *)card;
@end

@interface RamWorksPreferencesViewController : NSViewController
@end
