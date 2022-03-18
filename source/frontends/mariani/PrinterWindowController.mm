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
//#import "UserDefaults.h"
#import "ParallelInterface.h"
#import "Printers/AppleWriterPrinter.h"

@interface PrinterWindowController ()

@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet PrinterView *printerView;
@property AncientPrinterEmulationLibrary::AppleWriterPrinter *printer;
@property AncientPrinterEmulationLibrary::MarianiWriter *printerWriter;

@end

@implementation PrinterWindowController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.printerWriter = new AncientPrinterEmulationLibrary::MarianiWriter(self.printerView);
    self.printer = new AncientPrinterEmulationLibrary::AppleWriterPrinter(*self.printerWriter);
    Printer_SetPrinter(*self.printer);
    self.window.title = @(self.printer->Name().c_str());
    self.window.delegate = self;
    self.window.excludedFromWindowsMenu = YES;
    [self.window setNextResponder:self];
}

- (BOOL)acceptsFirstResponder {
    return YES;
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

@end
