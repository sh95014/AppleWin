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
#include "BasePrinter.h"

#define LOG_BASE_PRINTER_ENABLED 1
#define LOG_BASE_PRINTER_PLOTS 0
#define LOG_BASE_PRINTER_PRINTS 0

#if LOG_BASE_PRINTER_ENABLED
#define LOG_BASE_PRINTER(format, ...) LogOutput(format, __VA_ARGS__)
#else
#define LOG_BASE_PRINTER(...)
#endif

namespace AncientPrinterEmulationLibrary
{
    BasePrinter::BasePrinter(
        Writer& output,
        float pagePrintableAreaWidthInches,
        float pagePrintableAreaHeightInches,
        float pageLeftMarginInches,
        float pageRightMarginInches,
        float pageTopMarginInches,
        float pageBottomMarginInches,
        int dotsPerInch)
        :
        Printer(output)
    {
        DotsBetweeenChars = 1; // Reasonable default
        HorizontalPitchTwips = DpiToTwips(dotsPerInch); // Reasonable default
        SetLpi(6); // Reasonable default

        HorizontalDotsPerChar = 0; // Default should disable text output in the Writer
        VerticalDotsPerChar = 0; // Default should disable text output in the Writer

        PagePrintableAreaWidthTwips = (int)(pagePrintableAreaWidthInches * TwipsPerInch);
        PagePrintableAreaHeightInches = (int)(pagePrintableAreaHeightInches * TwipsPerInch);

        PageLeftMarginTwips = (int)(pageLeftMarginInches * TwipsPerInch);
        PageRightMarginTwips = (int)(pageRightMarginInches * TwipsPerInch);
        PageTopMarginTwips = (int)(pageTopMarginInches * TwipsPerInch);
        PageBottomMarginTwips = (int)(pageBottomMarginInches * TwipsPerInch);

        TwipsPerDot = TwipsPerInch / dotsPerInch;

        PageWidthTwips = PageLeftMarginTwips + PagePrintableAreaWidthTwips + PageRightMarginTwips;
        PageHeightTwips = PageTopMarginTwips + PagePrintableAreaHeightInches + PageBottomMarginTwips;
        PageX = PageLeftMarginTwips;
        PageY = PageTopMarginTwips;

        CharacterIsAdjacent = false;

        m_Output.SetPageMetrics((int)PageWidthTwips, (int)PageHeightTwips, (int)TwipsPerDot);
    }

    PITCHTYPE BasePrinter::DpiToTwips(PITCHTYPE dpi)
    {
        return TwipsPerInch / dpi;
    }

    PITCHTYPE BasePrinter::CpiToTwips(PITCHTYPE cpi)
    {
        return DpiToTwips(cpi * (HorizontalDotsPerChar + DotsBetweeenChars));
    }

    void BasePrinter::SetCharacterSize(int horizontalDotsPerChar, int verticalDotsPerChar)
    {
        HorizontalDotsPerChar = horizontalDotsPerChar;
        VerticalDotsPerChar = verticalDotsPerChar;
        UpdateFontSize();
    }

    void BasePrinter::SetCpi(PITCHTYPE cpi)
    {
        HorizontalPitchTwips = CpiToTwips(cpi);
        UpdateFontSize();
    }

    void BasePrinter::SetDpi(PITCHTYPE dpi)
    {
        HorizontalPitchTwips = DpiToTwips(dpi);
        UpdateFontSize();
    }

    void BasePrinter::SetLpi(PITCHTYPE lpi)
    {
        LineFeedPitchTwips = TwipsPerInch / lpi;
    }

    void BasePrinter::SetLpiInDecitwips(PITCHTYPE decitwips)
    {
        LineFeedPitchTwips = 10 * decitwips;
    }

    void BasePrinter::UpdateFontSize()
    {
        m_Output.SetFont(
            (int)(HorizontalDotsPerChar * HorizontalPitchTwips),
            (int)(VerticalDotsPerChar * TwipsPerDot));
    }

    void BasePrinter::NewPage()
    {
        m_Output.EndPage(); // End old page, but don't start one explicitly - the Writer will do that on demand

        PageX = PageLeftMarginTwips;
        PageY = PageTopMarginTwips;
    }

    void BasePrinter::CarriageReturn(bool lineFeed /* = false*/)
    {
        PageX = PageLeftMarginTwips;
        CharacterIsAdjacent = false;
        if (lineFeed)
        {
            LineFeed();
        }
    }

    bool BasePrinter::LineFeed(bool carriageReturn /* = false */)
    {
        PageY += LineFeedPitchTwips;
        if (PageY >= PageHeightTwips - PageBottomMarginTwips)
        {
            NewPage();
            return true;
        }
        if (carriageReturn)
        {
            CarriageReturn();
        }
        return false;
    }

    void BasePrinter::WrapX()
    {
        if (PageX >= PageWidthTwips - PageRightMarginTwips)
        {
            LineFeed(true);
        }
    }

    void BasePrinter::AddX(int x)
    {
        PageX += x * HorizontalPitchTwips;
        WrapX();
    }

    void BasePrinter::PlotPixel(int offsetX, int offsetY)
    {
        int x = (int)(PageX + (offsetX * HorizontalPitchTwips));
        int y = (int)(PageY + (offsetY * TwipsPerDot));
        m_Output.Plot(x, y);
        CharacterIsAdjacent = false;
#if LOG_BASE_PRINTER_PLOTS
        LOG_BASE_PRINTER("Plotted %d %d\n", x, y);
#endif
    }

    void BasePrinter::PrintCharacter(unsigned char byte)
    {
        char ascii = byte & 0x7F;
        switch (ascii)
        {
        // TODO: Handle Backspace, Tab, etc
        case '\n':
            LineFeed();
            break;

        case 0x0C: // Form Feed // TODO: Should be configurable to ignore
            do
            {
                m_Output.WriteCharacter((int)PageX, (int)PageY, '\n'); // Write Line Feeds
            }
            while (!LineFeed()); // Until end of page
            return; // Don't write Form Feed
            break;

        case '\r':
            CarriageReturn(); // TODO: Should be configurable for + Line Feed
            break;
        }
        int width = m_Output.WriteCharacter((int)PageX, (int)PageY, ascii, CharacterIsAdjacent);
        CharacterIsAdjacent = true;
        if (ascii >= 0x20)
        {
#if LOG_BASE_PRINTER_PRINTS
            LOG_BASE_PRINTER("Printed '%c' at %d, %d (width %d)\n", ascii, (int)PageX, (int)PageY, width);
#endif
            if (width > 0) // The returned value is the width (currently not used) or <= 0 for an error
            {
                PageX += (HorizontalDotsPerChar + 1) * HorizontalPitchTwips;
                if (DotsBetweeenChars > 1) // Assume WriteCharacter inserts one dot space between characters
                {
                    PageX += (DotsBetweeenChars - 1) * HorizontalPitchTwips; // Add extra space between characters
                }
                WrapX();
            }
        }
    }
}
