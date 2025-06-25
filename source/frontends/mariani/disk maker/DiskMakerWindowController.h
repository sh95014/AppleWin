//
//  DiskMakerWindowController.h
//  Mariani
//
//  Created by sh95014 on 6/24/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DiskMakerWindowController : NSWindowController <NSOpenSavePanelDelegate>

@property (assign) int slot;
@property (assign) int drive;

- (void)selectHardDisk;

@end

NS_ASSUME_NONNULL_END
