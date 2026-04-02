//
//  SlotPreferencesViewControllers.h
//  Mariani
//
//  Created by sh95014 on 4/2/26.
//

#import <AppKit/Appkit.h>

#include "StdAfx.h"
#import "Disk.h"
#import "Mockingboard.h"

@interface DiskIIPreferencesViewController : NSViewController
- (void)setCard:(Disk2InterfaceCard *)card;
@end

@interface MockingboardPreferencesViewController : NSViewController
- (void)setCard:(MockingboardCard *)card;
@end
