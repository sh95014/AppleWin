//
//  PrinterPageViewController.m
//  Mariani
//
//  Created by sh95014 on 3/14/22.
//

#import "PrinterPageViewController.h"

@interface PrinterPageViewController ()

@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet PrinterView *printerView;

@end

@implementation PrinterPageViewController

- (void)awakeFromNib {
    [super awakeFromNib];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.printerView.pageCount;
}

#pragma mark - NSTableViewDelegate

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    // 10pt per inch, so 8.5x11 is 85x110
    return 110;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSImage *image = [NSImage imageWithSystemSymbolName:@"doc.richtext" accessibilityDescription:@""];
    NSImageView *imageView = [NSImageView imageViewWithImage:image];
    imageView.frame = CGRectMake(0, 0, 85, 110);
    imageView.imageFrameStyle = NSImageFrameGrayBezel;
    return imageView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self.printerView showPage:self.tableView.selectedRow];
}

#pragma mark - PrinterViewDelegate

- (void)printerViewPageAdded:(PrinterView *)printerView {
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.printerView.pageCount - 1];
    [self.tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationSlideDown];
}

@end
