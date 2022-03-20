// AppleWin : An Apple //e emulator for Windows
//
// AppleWin is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// AppleWin is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with AppleWin; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

// Epson FX-80 Printer Emulator
// Adapted from Ancient Printer Emulation Libarary (APEL) by Nick Westgate

#pragma once
#include <string>
#include "BasePrinter.h"

#include <stdio.h>

namespace AncientPrinterEmulationLibrary
{
    class EpsonFX80Printer : public BasePrinter
    {
    public:
        EpsonFX80Printer(Writer& output);

        virtual std::string Name() { return "Epson FX-80"; }

        virtual int Send(unsigned char byte);

    protected:
        enum class Mode
        {
            TEXT,
            CODE,
            ARG,
            DATA,
            SKIP,
        };

        void HandleData(unsigned char byte);
        void ExpectText();
        void ExpectArg(unsigned int length);
        void ExpectData(unsigned int length);
        void ConsumeData();
        void PlotGraphics(unsigned char byte);

        Mode          m_Mode;
        unsigned char m_Code;
        unsigned int  m_Arg;
        unsigned int  m_ArgLengthExpected;
        unsigned int  m_ArgLengthReceived;
        unsigned int  m_DataLengthExpected;
        unsigned int  m_DataLengthReceived;
        
        PITCHTYPE     m_SavedHorizontalPitchTwips;

        FILE *file = 0;
    };
}
