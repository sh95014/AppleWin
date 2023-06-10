//
//  PrinterWindowController.h
//  Mariani
//
//  Created by sh95014 on 3/14/22.
//

#import <Cocoa/Cocoa.h>
#import "PrinterView.h"

@protocol PrinterWindowControllerDelegate <NSObject>

- (void)printerWindowDidClose;

@end

@interface PrinterWindowController : NSWindowController<NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, PrinterViewDelegate>

@property (nullable, weak) id<PrinterWindowControllerDelegate> delegate;

@property (readonly) NSString * _Nullable printerName;
- (BOOL)togglePrinterWindow;

- (void)emulationHardwareChanged;

@end
