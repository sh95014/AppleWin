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
// As specified in "Epson FX Series Printer User's Manual Vol. 1"

#include "stdafx.h"
#include "EpsonFX80Printer.h"

#define ESC         0x1B

namespace AncientPrinterEmulationLibrary
{
    EpsonFX80Printer::EpsonFX80Printer(Writer& output)
        :
        BasePrinter(
            output,
            8, // Maximum line width is 8 inches
            11, // Assuming Letter size - TODO: Get paper size from the Writer(?)
            0.25, // Assuming Letter size - TODO: Get these margins as parameters?
            0.25, // Assuming Letter size
            0,
            0,
            72) // (Manual page 97)
    {
        SetCharacterSize(5, 7); // Standard characters are 5 x 7 dots (Manual page 51)
        DotsBetweeenChars = 1; // Standard characters separated horizontally by 1 dot (Manual page 51)
        SetCpi(10); // Default is Pica = 10 CPI, 80 characters per 8 inch line (Manual page 52)
        SetLpi(6); // Default is 6 LPI = 54 DPI = 66 lines per 11 inch page (Manual page 93)
        
        m_Mode = Mode::TEXT;
    }

    int EpsonFX80Printer::Send(unsigned char byte)
    {
#if 1
        switch (m_Mode)
        {
        case Mode::TEXT:
            if (byte == ESC)
                m_Mode = Mode::CODE;
            else
                PrintCharacter(byte);
            break;

        case Mode::CODE:
        case Mode::ARG:
        case Mode::DATA:
            HandleData(byte);
            break;

        case Mode::SKIP:
            if (byte == ESC)
                m_Mode = Mode::CODE;
            break;
        }
#else
        if (!file) {
            file = fopen("/Users/steven/Desktop/printer.bin", "wb");
        }
        fwrite(&byte, 1, 1, file);
        fflush(file);
#endif
        return 0;
    }

    void EpsonFX80Printer::HandleData(unsigned char byte)
    {
        switch (m_Mode)
        {
        case Mode::CODE:
            m_Code = byte;
            break;
        case Mode::ARG:
            // successive bytes are placed in higher order
            m_Arg |= byte << (8 * m_ArgLengthReceived);
            if (++m_ArgLengthReceived < m_ArgLengthExpected)
                return;
            break;
        default:
            break;
        }
        
        switch (m_Code)
        {
            case '0':
                if (m_Mode == Mode::CODE)
                {
                    SetLpi(8);
                    ExpectText();
                }
                break;
            case '1':
                if (m_Mode == Mode::CODE)
                {
                    SetLpiInDecitwips(14);  // 7/72 inch
                    ExpectText();
                }
                break;
            case '2':
                if (m_Mode == Mode::CODE)
                {
                    SetLpi(6);
                    ExpectText();
                }
                break;
            case 'A':
                switch (m_Mode)
                {
                case Mode::CODE:
                    ExpectArg(1);
                    break;
                case Mode::ARG:
                    if (m_Arg > 85)
                        m_Arg = 85;
                    SetLpiInDecitwips(2 * m_Arg);
                    ExpectText();
                    break;
                default:
                    break;
                }
                break;
            case 'L':
                // Low-speed double-density
                switch (m_Mode)
                {
                case Mode::CODE:
                    m_SavedHorizontalPitchTwips = HorizontalPitchTwips;
                    SetDpi(120);
                    ExpectArg(2);
                    break;
                case Mode::ARG:
                    ExpectData(m_Arg);
                    break;
                case Mode::DATA:
                    PlotGraphics(byte);
                    ConsumeData();
                    if (m_Mode != Mode::DATA)
                        HorizontalPitchTwips = m_SavedHorizontalPitchTwips;
                    break;
                default:
                    break;
                }
                break;
        }
    }

    void EpsonFX80Printer::ExpectText()
    {
        m_Mode = Mode::TEXT;
    }

    void EpsonFX80Printer::ExpectArg(unsigned int length)
    {
        m_Mode = Mode::ARG;
        m_Arg = 0;
        m_ArgLengthExpected = length;
        m_ArgLengthReceived = 0;
    }

    void EpsonFX80Printer::ExpectData(unsigned int length)
    {
        m_Mode = Mode::DATA;
        m_DataLengthExpected = length;
        m_DataLengthReceived = 0;
    }

    void EpsonFX80Printer::ConsumeData()
    {
        if (++m_DataLengthReceived >= m_DataLengthExpected)
            m_Mode = Mode::TEXT;
    }

    void EpsonFX80Printer::PlotGraphics(unsigned char byte)
    {
        for (int y = 0; y < 7; y++)
        {
            // top pin is higher bit, Manual page 137
            if (byte & (0x40 >> y))
            {
                PlotPixel(0, y);
            }
        }
        AddX(1);
    }

}
