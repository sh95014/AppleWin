// Copyright 2017 Nick Westgate
//
// This file is part of the Ancient Printer Emulation Libarary (APEL).
//
// APEL is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 2 of the License, or
// (at your option) any later version.
//
// APEL is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with APEL. If not, see <http://www.gnu.org/licenses/>.

#include "stdafx.h"
#include "AppleWriterPrinter.h"

#define LOG_APPLE_WRITER_ENABLED 0
#define LOG_APPLE_WRITER_COMMANDS 0

#if LOG_APPLE_WRITER_ENABLED
#define LOG_APPLE_WRITER(format, ...) LogOutput(format, __VA_ARGS__)
#else
#define LOG_APPLE_WRITER(...)
#endif

#if LOG_APPLE_WRITER_COMMANDS
#define LOG_COMMAND(format, ...) LOG_APPLE_WRITER(format, __VA_ARGS__)
#else
#define LOG_COMMAND(...)
#endif

namespace AncientPrinterEmulationLibrary
{
    AppleWriterPrinter::AppleWriterPrinter(Writer& output)
        :
        BasePrinter(
            output,
            8, // Maximum line width is 8 inches (Manual page 101)
            11, // Assuming Letter size - TODO: Get paper size from the Writer(?)
            0.25, // Assuming Letter size - TODO: Get these margins as parameters?
            0.25, // Assuming Letter size
            0,
            0,
            72) // (Manual page 72 - Print head pins are 72 DPI)
    {
        SetCharacterSize(7, 9); // Standard characters are 7 x 9 dots (Manual page 11 says 7 x 8, but look at the characters on page 92)
        DotsBetweeenChars = 1; // Standard characters separated horizontally by 1 dot (Manual page 11)
        SetCpi(12); // Default is Elite = 12 CPI = 96 DPI = 96 characters per 8 inch line (Manual page 40)
        SetLpi(6); // Default is 6 LPI = 54 DPI = 66 lines per 11 inch page (Manual page 48)

        m_Mode = Mode::TEXT;
    }

    void AppleWriterPrinter::ConsumeData()
    {
        if (++m_DataLength == m_DataLengthExpected)
            m_Mode = Mode::TEXT;
    }

    void AppleWriterPrinter::ExpectArg(int length)
    {
        m_Mode = Mode::ARG;
        m_Arg.clear();
        m_ArgLengthExpected = length;
    }

    void AppleWriterPrinter::ExpectData(int length)
    {
        m_Mode = Mode::DATA;
        m_DataLength = 0;
        m_DataLengthExpected = length;
    }

    void AppleWriterPrinter::ExpectText()
    {
        m_Mode = Mode::TEXT;
    }

    int AppleWriterPrinter::GetArgInt()
    {
        return atoi(m_Arg.c_str());
    }

    void AppleWriterPrinter::HandleData(unsigned char byte)
    {
        switch (m_Mode)
        {
        case Mode::CODE:
            m_Code = (byte & 0x7F);
            break;

        case Mode::ARG:
            m_Arg += (byte & 0x7F);
            if (m_Arg.length() < m_ArgLengthExpected)
                return;
            break;
        }

        int arg;
        switch (m_Code)
        {
        case '>': // Left-to-right printing only (Manual page 46)
            switch (m_Mode)
            {
            case Mode::CODE:
                // TODO: This is the default; need to handle '<'
                LOG_COMMAND("ESC %c - Left-to-right printing only\n", m_Code);
                ExpectText();
            }
            break;

        case 'A': // Line Feed Pitch - 6 LPI (Manual page 48)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetLpi(6); // 6 LPI = 54 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Line Feed Pitch - 6 LPI\n", m_Code);
            }
            break;

        case 'B': // Line Feed Pitch - 8 LPI (Manual page 48)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetLpi(8); // 8 LPI = 64 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Line Feed Pitch - 8 LPI\n", m_Code);
            }
            break;

        case 'e': // Character Pitch Semicondensed - 13.4 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetDpi(107); // 107 DPI = 13.4 CPI
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Semicondensed - 13.4 CPI\n", m_Code);
            }
            break;

        case 'E': // Character Pitch Elite - 12 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetCpi(12); // 12 CPI = 96 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Elite - 12 CPI\n", m_Code);
            }
            break;

        case 'n': // Character Pitch Extended - 9 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetCpi(9); // 9 CPI = 72 DPI - best for graphics (Manual page 72 - Dot Spacing)
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Extended - 9 CPI\n", m_Code);
            }
            break;

        case 'N': // Character Pitch Pica - 10 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetCpi(10); // 10 CPI = 80 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Pica - 10 CPI\n", m_Code);
            }
            break;

        case 'p': // Character Pitch Pica proportional - 18 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetCpi(18); // 18 CPI = 144 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Pica proportional - 18 CPI\n", m_Code);
            }
            break;

        case 'P': // Character Pitch Elite proportional - 20 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetCpi(20); // 20 CPI = 160 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Elite proportional - 20 CPI\n", m_Code);
            }
            break;

        case 'q': // Character Pitch Condensed - 15 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetCpi(15); // 15 CPI = 120 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Condensed - 15 CPI\n", m_Code);
            }
            break;

        case 'Q': // Character Pitch Ultracondensed - 17 CPI (Manual page 40)
            switch (m_Mode)
            {
            case Mode::CODE:
                SetCpi(17); // 17 CPI = 136 DPI
                ExpectText();
                LOG_COMMAND("ESC %c - Character Pitch Ultracondensed - 17 CPI\n", m_Code);
            }
            break;

        case 'G': // Column-Oriented Graphics (Manual page 71)
        // Fall through to 'S'
        case 'S': // Column-Oriented Graphics (Manual page 71)
            switch (m_Mode)
            {
            case Mode::CODE:
                ExpectArg(4); // nnnn = number of following data bytes
                break;

            case Mode::ARG:
                arg = GetArgInt();
                ExpectData(arg); // Following bytes are graphics data
                LOG_COMMAND("ESC %c %04d - Column-Oriented Graphics (%d bytes) \n", m_Code, arg, arg);
                break;

            case Mode::DATA:
                PlotGraphics(byte); // Graphics data is column of dots (Manual page 72)
                ConsumeData();
                break;
            }
            break;

        case 'T': // Line Feed Pitch in Half Points (Manual page 48)
            switch (m_Mode)
            {
            case Mode::CODE:
                ExpectArg(2); // nn half points between lines
                break;

            case Mode::ARG: // T16 = 72 DPI - best for graphics (Manual page 72 - Dot Spacing)
                arg = GetArgInt();
                LOG_COMMAND("ESC %c %02d - Line Feed Pitch in Half Points ", m_Code, arg);
                if (arg == 0)
                {
                    ExpectText(); // TODO: Manual page 48 says 0 is "ignored"; should test
                    LOG_COMMAND("(0 ignored)\n");
                }
                else
                {
                    SetLpiInDecitwips(arg); // TODO: This should change the page length (Manual Page 48 - By the Way)
                    ExpectText();
                    LOG_COMMAND(" = 144/%d = %g LPI = %g DPI\n",
                        arg,
                        (double)144 / arg,
                        (double)144 * 8 / arg);
                }
                break;
            }
            break;

        default:
            switch (m_Mode)
            {
            case Mode::CODE:
                LOG_APPLE_WRITER("Unhandled code '%c'\n", m_Code);
                m_Mode = Mode::SKIP;
            }
        }
    }

    void AppleWriterPrinter::HandleText(unsigned char byte)
    {
        PrintCharacter(byte);
    }

    int AppleWriterPrinter::Send(unsigned char byte)
    {
        switch (m_Mode)
        {
        case Mode::TEXT:
            if ((byte & 0x7F) == 0x1B) // Some programs send 8-bit ESC, e.g. MousePaint
                m_Mode = Mode::CODE;
            else
                HandleText(byte);
            break;

        case Mode::CODE:
        case Mode::ARG:
        case Mode::DATA:
            HandleData(byte);
            break;

        case Mode::SKIP:
            if ((byte & 0x7F) == 0x1B) // Some programs send 8-bit ESC, e.g. MousePaint
                m_Mode = Mode::CODE;
            else
            {
                LOG_APPLE_WRITER("Skipped 0x%X", byte);
            }
            break;
        }
        return 0;
    }

    void AppleWriterPrinter::PlotGraphics(unsigned char byte)
    {
        unsigned char mask = 0x01;
        for (int y = 0; y <= 7; y++)
        {
            if (byte & mask)
            {
                PlotPixel(0, y);
            }
            mask <<= 1;
        }
        AddX(1);
    }
}
