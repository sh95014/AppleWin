//
//  PrinterWindowController.mm
//  Mariani
//
//  Created by sh95014 on 3/14/22.
//

#import "PrinterWindowController.h"

#import "windows.h"
#import "context.h"
#import "CardManager.h"
#import "Core.h"

#import "MarianiWriter.h"
#import "ParallelInterface.h"
#import "Printers/AppleWriterPrinter.h"

@interface PrinterWindowController ()

@property (strong) IBOutlet NSTableView *tableView;
@property (strong) NSMutableArray<NSImage *> *thumbnailImages;
@property (strong) NSMutableSet *pagesPendingUpdate;
@property (strong) NSDate *lastUpdate;
@property (strong) NSTimer *updateTimer;

@property (strong) IBOutlet PrinterView *printerView;
@property AncientPrinterEmulationLibrary::AppleWriterPrinter *printer;
@property AncientPrinterEmulationLibrary::MarianiWriter *printerWriter;

@end

@implementation PrinterWindowController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    NSImage *thumbnail = [self.printerView imageThumbnailOfPage:0 withDPI:10];
    self.thumbnailImages = [NSMutableArray arrayWithObject:thumbnail];
    self.pagesPendingUpdate = [NSMutableSet set];
    self.lastUpdate = [NSDate date];
    
    self.printerWriter = new AncientPrinterEmulationLibrary::MarianiWriter(self.printerView);
    self.printer = new AncientPrinterEmulationLibrary::AppleWriterPrinter(*self.printerWriter);
    Printer_SetPrinter(*self.printer);
    self.window.title = @(self.printer->Name().c_str());
    self.window.delegate = self;
    self.window.excludedFromWindowsMenu = YES;
    [self.window setNextResponder:self];
}

- (IBAction)printWindow:(id)sender {
    if ([self.window isKeyWindow]) {
        NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:self.printerView];
        printOperation.printInfo.topMargin = 0;
        printOperation.printInfo.leftMargin = 0;
        printOperation.printInfo.rightMargin = 0;
        printOperation.printInfo.bottomMargin = 0;
        [printOperation setCanSpawnSeparateThread:YES];
        [printOperation runOperation];
    }
}

#pragma mark - NSWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (sender == self.window) {
        // just hide, don't actually close
        [self.window orderOut:sender];
        [self.delegate printerWindowDidClose];
        return NO;
    }
    return YES;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.printerView.pageCount;
}

#pragma mark - NSTableViewDelegate

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    // 10pt per inch, so 8.5x11 is 85x110
    return 110 + 10;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSImage *image = self.thumbnailImages[row];
    NSImageView *imageView = [NSImageView imageViewWithImage:image];
    imageView.frame.size = image.size;
    return imageView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger pageNumber = self.tableView.selectedRow;
    [self.printerView showPage:pageNumber];
}

#pragma mark - PrinterViewDelegate

- (void)printerViewPageAdded:(PrinterView *)printerView {
    NSInteger pageNumber = self.printerView.pageCount - 1;

    NSImage *thumbnail = [self.printerView imageThumbnailOfPage:pageNumber withDPI:10];
    [self.thumbnailImages addObject:thumbnail];
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:pageNumber];
    [self.tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationSlideDown];
}

- (void)printerView:(PrinterView *)printerView printedToPage:(NSInteger)pageNumber {
    if (![self.pagesPendingUpdate containsObject:@(pageNumber)]) {
        [self.pagesPendingUpdate addObject:@(pageNumber)];
    }
    
    if ([self.lastUpdate timeIntervalSinceNow] < -1.0) {
        [self updateThumbnails];
        [self.updateTimer invalidate];
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            if (self.pagesPendingUpdate.count > 0) {
                [self updateThumbnails];
            }
        }];
    }
}

#pragma mark -

- (NSString *)printerName {
    return @(self.printer->Name().c_str());
}

- (BOOL)togglePrinterWindow {
    if (self.window.isVisible) {
        [self.window orderOut:self];
        return NO;
    }
    else {
        [self.window makeKeyAndOrderFront:self];
        return YES;
    }
}

- (void)emulationHardwareChanged {
    BOOL hasPrinter = NO;
    CardManager &cardManager = GetCardMgr();
    for (int slot = SLOT0; slot < NUM_SLOTS; slot++) {
        if (cardManager.QuerySlot(slot) == CT_GenericPrinter) {
            hasPrinter = YES;
            break;
        }
    }
    if (!hasPrinter && self.window) {
        [self.window orderOut:self];
    }
}

- (void)updateThumbnails {
    for (NSNumber *number in self.pagesPendingUpdate) {
        NSInteger pageNumber = [number integerValue];
        self.thumbnailImages[pageNumber] = [self.printerView imageThumbnailOfPage:pageNumber withDPI:10];
        NSIndexSet *columnIS = [NSIndexSet indexSetWithIndex:0];
        NSIndexSet *rowIS = [NSIndexSet indexSetWithIndex:pageNumber];
        [self.tableView reloadDataForRowIndexes:rowIS columnIndexes:columnIS];
    }
    [self.pagesPendingUpdate removeAllObjects];
    self.lastUpdate = [NSDate date];
}

@end
