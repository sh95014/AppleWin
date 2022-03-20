//
//  MarianiWriter.cpp
//  Mariani
//
//  Created by sh95014 on 3/12/22.
//

#import <Cocoa/Cocoa.h>
#import "PrinterView.h"
#import "MarianiWriter.h"

// We want to collate the incoming characters into strings so that the printer
// view isn't overwhelmed with objects, but that requires it to fudge kerning.
// Disable COLLATE_STRINGS to get back to the per-character behavior to check
// for accuracy.
#define COLLATE_STRINGS

// "Twips per point": BasePrinter uses integer "twips", which is 1/20 of a point
#define TWIPS_TO_PT(x)      ((CGFloat)x / 20.0)

namespace AncientPrinterEmulationLibrary
{
    MarianiWriter::MarianiWriter(PrinterView *printerView) :
        myPrinterView(printerView)
    {
    }

    void MarianiWriter::EndPage()
    {
        Flush();
        [myPrinterView addPage];
    }

    int MarianiWriter::WriteCharacter(int x, int y, char character, bool isAdjacent)
    {
        if (myPrinterView) {
#ifdef COLLATE_STRINGS
            if (!isAdjacent)
#endif
            {
                Flush();
            }
            if (isprint(character)) {
                if (string == nil) {
                    string = [NSString stringWithFormat:@"%c", character];
                    stringX = x;
                    stringY = y;
                }
                else {
                    string = [string stringByAppendingFormat:@"%c", character];
                }
                
                // BasePrinter assumes its own width and ignores the return
                // value, so don't bother computing yet. A small positive number
                // should ensure ugly overlaps if we're paired with a Printer that
                // actually does.
                return 3;
            }
            else {
                return 1;
            }
        }
        return 0;
    }

    int MarianiWriter::SetFont(int textWidth, int textHeight)
    {
        [myPrinterView setFontSize:CGSizeMake(TWIPS_TO_PT(textWidth), TWIPS_TO_PT(textHeight))];
        return 0;
    }

    void MarianiWriter::Flush()
    {
        // output the string accumulated so far to the Writer
        if (string.length > 0) {
            // BasePrinter coordinates are in 1/20pt
            [myPrinterView addString:string atPoint:CGPointMake(TWIPS_TO_PT(stringX), TWIPS_TO_PT(stringY))];
        }
        string = nil;
    }

    int MarianiWriter::Plot(int x, int y)
    {
        [myPrinterView plotAtPoint:CGPointMake(TWIPS_TO_PT(x), TWIPS_TO_PT(y))];
        return 0;
    }
}
