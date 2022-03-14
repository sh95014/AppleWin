//
//  MarianiWriter.h
//  Mariani
//
//  Created by sh95014 on 3/12/22.
//

#pragma once

#import <Cocoa/Cocoa.h>
#import "Printers/Writer.h"
#import "PrinterView.h"

namespace AncientPrinterEmulationLibrary
{
    class MarianiWriter : public Writer
    {
    public:
        MarianiWriter(PrinterView *printerView);
        virtual void EndPage();
        virtual int WriteCharacter(int x, int y, char character, bool isAdjacent = false);
        
    private:
        PrinterView *myPrinterView;
        int stringX;
        int stringY;
        NSString *string;
        
        void Flush();
    };
}
