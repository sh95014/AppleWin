//
//  DisassemblyTableViewController.h
//  Mariani
//
//  Created by sh95014 on 5/29/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DisassemblyTableViewControllerDelegate <NSObject>

- (void)sendDebuggerCommand:(NSString *)command refresh:(BOOL)shouldRefresh;
- (void)refreshBookmarks;

@end

@interface DisassemblyTableViewController : NSViewController
    <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>

@property (weak) id<DisassemblyTableViewControllerDelegate> delegate;

- (id)initWithTableView:(NSTableView *)tableView;
- (void)reloadData:(BOOL)syncPC;
- (void)recenterAtAddress:(NSUInteger)address;
- (void)selectBookmark:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
