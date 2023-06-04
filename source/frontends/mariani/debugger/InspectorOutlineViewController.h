//
//  InspectorOutlineViewController.h
//  Mariani
//
//  Created by sh95014 on 6/1/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol InspectorOutlineViewControllerDelegate <NSObject>

- (void)sendDebuggerCommand:(NSString *)command refresh:(BOOL)shouldRefresh;

@end

@interface InspectorOutlineViewController : NSViewController<NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate>

@property (weak) id<InspectorOutlineViewControllerDelegate> delegate;

- (id)initWithOutlineView:(NSOutlineView *)outlineView;
- (void)themeDidChange;
- (void)refresh;

@end

NS_ASSUME_NONNULL_END
