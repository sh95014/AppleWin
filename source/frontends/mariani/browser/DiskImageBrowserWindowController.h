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

@interface BASICListingView : NSTextView
@property (strong) NSData *data;
@property (assign) BOOL isApplesoftBASIC;
@end

NS_ASSUME_NONNULL_END
