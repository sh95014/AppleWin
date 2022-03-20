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
#include <iostream>

#define ESC         0x1B

#define DUMP_OUTPUT

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
#ifdef DUMP_OUTPUT
        if (!file) {
            file = fopen("/tmp/printer.bin", "wb");
        }
        fwrite(&byte, 1, 1, file);
        fflush(file);
#endif // DUMP_OUTPUT

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
        }
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
        case '!': // Master Select
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code) + " " + std::string(1, m_Arg));
            }
            break;
        case '#': // Accepts eighth bit as is from computer
            // This "returns the system to normal by turning the high-order control off"
            // but I don't really understand what that means in our context.
            // Manual page 310
            ExpectText();
            break;
        case '%': // Selects a character set
            if (m_Mode == Mode::CODE)
                ExpectArg(2);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case '&': // Selects characters to be defined
            ErrorUnparsed("ESC " + std::string(1, m_Code));
            break;
        case '*': // Selects graphics mode
            switch (m_Mode)
            {
            case Mode::CODE:
                m_SavedHorizontalPitchTwips = HorizontalPitchTwips;
                ExpectArg(3);
                break;
            case Mode::ARG:
                // first byte is graphics mode
                switch (m_Arg & 0xFF) {
                case 0:
                    SetDpi(60); // Single density
                    break;
                case 1:
                    SetDpi(120); // Low-speed double density
                    break;
                case 2:
                    SetDpi(120); // High-speed double density
                    break;
                case 3:
                    SetDpi(240); // Quadruple density
                    break;
                case 4:
                    SetDpi(80); // Epson QX-10
                    break;
                case 5:
                    SetDpi(72); // One-to-one (plotter)
                    break;
                case 6:
                    SetDpi(90); // Other CRT screens
                    break;
                }
                // bytes 2 and 3 are length
                ExpectData(m_Arg >> 8);
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
        case '-': // Selects underline mode
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code) + " " + std::string(1, m_Arg));
            }
            break;
        case '/': // Selects channel
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case '0': // Sets line spacing to 1/8"
            if (m_Mode == Mode::CODE)
            {
                SetLpi(8);
                ExpectText();
            }
            break;
        case '1': // Sets line spacing to 7/72"
            if (m_Mode == Mode::CODE)
            {
                SetLpiInDecitwips(14);
                ExpectText();
            }
            break;
        case '2': // Sets line spacing to 1/6"
            if (m_Mode == Mode::CODE)
            {
                SetLpi(6);
                ExpectText();
            }
            break;
        case '3': // Sets line spacing to n/216"
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case '4': // Turns italic mode on
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case '5': // Turns italic mode off
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case '6': // Enables printing of control codes 128-159
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case '7': // Returns codes 128-159 to control codes
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case '8': // Turns paper-out sensor off
            // not applicable, we're not going to run out of paper
            ExpectText();
            break;
        case '9': // Turns paper-out sensor on
            // not applicable, we're not going to run out of paper
            ExpectText();
            break;
        case ':': // Copies ROM characters to the RAM area
            ErrorUnparsed("ESC " + std::string(1, m_Code));
            break;
        case '<': // Turns on the one-line unidirectional mode
            // unidirectional mode is used to mitigate printhead alignment
            // issues and is meaningless here.
            ExpectText();
            break;
        case '=': // Sets high-order bit off
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case '>': // Sets high-order bit on
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case '?': // Reassigns an alternate graphics code
            if (m_Mode == Mode::CODE)
                ExpectArg(2);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case '@': // Reset code
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'A': // Sets line spacing to n/72"
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
        case 'B': // Sets vertical tabs
            ErrorUnparsed("ESC " + std::string(1, m_Code));
            break;
        case 'C': // Sets the form length
            ErrorUnparsed("ESC " + std::string(1, m_Code));
            break;
        case 'D': // Sets horizontal tabs
            ErrorUnparsed("ESC " + std::string(1, m_Code));
            break;
        case 'E': // Turns emphasized mode on
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'F': // Turns emphasized mode off
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'G': // Turns double-strike mode on
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'H': // Turns double-strike mode off
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'I': // Returns codes 0-31 to control codes
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'J': // Produces an immediate one-time line feed of n/216" without a carriage return
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'K': // Turns single-density graphics mode on
            switch (m_Mode)
            {
            case Mode::CODE:
                m_SavedHorizontalPitchTwips = HorizontalPitchTwips;
                SetDpi(60);
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
        case 'L': // Turns low-speed double-density graphics mode on
        case 'Y': // Turns high-speed double-density graphics mode on
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
        case 'M': // Turns elite mode on
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'N': // Sets skip-over-perforation
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'O': // Turns skip-over-perforation off
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'P': // Turns elite mode off
            // Manual page 277 says this shouldn't happen if compressed mode is on
            SetCpi(10);
            break;
        case 'Q': // Sets the right margin
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'R': // Selects an international character set
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'S': // Turns superscript/subscript mode on
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'T': // Turns either script mode off
            ErrorUnsupported("ESC " + std::string(1, m_Code));
            break;
        case 'U': // Sets continuous unidirectional mode
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                // unidirectional mode is used to mitigate printhead alignment
                // issues and is meaningless here.
                ExpectText();
            }
            break;
        case 'W': // Sets expanded mode
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
//      case 'Y':
//          apparently "same density as L but cannot print two adjacent dots
//          in the same row, so handled above at case 'L'.
        case 'Z': // Turns quadruple-density graphics mode on
            switch (m_Mode)
            {
            case Mode::CODE:
                m_SavedHorizontalPitchTwips = HorizontalPitchTwips;
                SetDpi(240);
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
        case '^': // Enters nine-pin graphics mode
            switch (m_Mode)
            {
            case Mode::CODE:
                ExpectArg(3);
                break;
            case Mode::ARG:
                // first arg byte is density, which we ignore so we can ignore
                // the data
                ExpectData(m_Arg >> 8);
                break;
            case Mode::DATA:
                ConsumeData();
                ErrorUnsupported("ESC " + std::string(1, m_Code));
                break;
            default:
                break;
            }
            break;
        case 'b': // Stores channels of vertical tab stops
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'i': // Sets immediate-print mode
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                // doesn't seem relevant to our context
                ExpectText();
            }
            break;
        case 'j': // Turns reverse feed on
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'l': // Sets left margin
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 'p': // Sets proportional mode
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                ErrorUnsupported("ESC " + std::string(1, m_Code));
            }
            break;
        case 's': // Sets half-speed mode
            if (m_Mode == Mode::CODE)
                ExpectArg(1);
            else
            {
                // noise reduction, irrelevant to our context
                ExpectText();
            }
            break;
        default:
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

    void EpsonFX80Printer::ErrorUnknown(std::string command)
    {
        std::cerr << "Error: unknown command '" << command << "', output probably garbled.\n";
        m_Mode = Mode::TEXT;
    }

    void EpsonFX80Printer::ErrorUnparsed(std::string command)
    {
        std::cerr << "Error: unparsed command '" << command << "', output probably garbled.\n";
        m_Mode = Mode::TEXT;
    }

    void EpsonFX80Printer::ErrorUnsupported(std::string command)
    {
        std::cerr << "Error: ignored command '" << command << "'.\n";
        m_Mode = Mode::TEXT;
    }

}
