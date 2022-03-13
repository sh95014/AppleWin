//
//  MarianiWriter.cpp
//  Mariani
//
//  Created by sh95014 on 3/12/22.
//

#import <Cocoa/Cocoa.h>
#import "PrinterView.h"
#import "MarianiWriter.h"

namespace AncientPrinterEmulationLibrary
{
    MarianiWriter::MarianiWriter(PrinterView *printerView) :
        myPrinterView(printerView),
        myFont([NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightRegular])
    {
        
    }

    int MarianiWriter::WriteCharacter(int x, int y, char character)
    {
        if (myPrinterView) {
            NSString *string = [NSString stringWithFormat:@"%c", character];
            [myPrinterView addString:string atPoint:CGPointMake((CGFloat)x / 20.0, (CGFloat)y / 20)];
            return (int)(myFont.maximumAdvancement.width * 20.0);
        }
        return 0;
    }
}
