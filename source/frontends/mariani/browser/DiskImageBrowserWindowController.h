//
//  DiskImageBrowserWindowController.h
//  Mariani
//
//  Created by sh95014 on 1/8/22.
//

#import <Cocoa/Cocoa.h>
#import "DiskImageWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiskImageBrowserWindowController : NSWindowController <NSWindowDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource>

- (instancetype)initWithDiskImageWrapper:(DiskImageWrapper *)wrapper;

@end

NS_ASSUME_NONNULL_END
