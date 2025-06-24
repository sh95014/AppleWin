//
//  MarianiDriveButton.h
//  Mariani
//
//  Created by sh95014 on 6/23/25.
//

#import <Foundation/Foundation.h>
#import "DiskImageBrowserWindowController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MarianiDriveButton : NSButton <DiskImageBrowserDelegate, NSOpenSavePanelDelegate>

@property (nonatomic) NSInteger slot;
@property (nonatomic) NSInteger drive;

+ (instancetype)buttonForFloppyDrive:(int)drive inSlot:(int)slot;
+ (instancetype)buttonForHardDrive:(int)drive inSlot:(int)slot;
+ (NSInteger)buttonWidth;

- (void)updateDriveLight;

- (void)openDiskImage:(id)sender;
- (void)createDiskImage:(id)sender;

@end

NS_ASSUME_NONNULL_END
