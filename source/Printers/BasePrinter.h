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

#pragma once
#include "Printer.h"

// For experimenting with rounding errors
#if 1
#define PITCHTYPE int
#else
#define PITCHTYPE double
#endif

namespace AncientPrinterEmulationLibrary
{
    class BasePrinter : public Printer
    {
    public:
        BasePrinter(
            Writer& output,
            float pagePrintableAreaWidthInches,
            float pagePrintableAreaHeightInches,
            float pageLeftMarginInches,
            float pageRightMarginInches,
            float pageTopMarginInches,
            float pageBottomMarginInches,
            int dotsPerInch);

        const int PointsPerInch = 72; // 1 point is 1/72 of an inch
        const int TwipsPerInch = PointsPerInch * 20; // 1440 (1 twip is a twentieth of a point = 1/20 * 1/72 = 1/1440 of an inch)

    protected:
        PITCHTYPE PagePrintableAreaWidthTwips;
        PITCHTYPE PagePrintableAreaHeightInches;

        int PageLeftMarginTwips;
        int PageRightMarginTwips;
        int PageTopMarginTwips;
        int PageBottomMarginTwips;

        int HorizontalDotsPerChar;
        int VerticalDotsPerChar;
        int DotsBetweeenChars;
        int TwipsPerDot;

        PITCHTYPE PageWidthTwips;
        PITCHTYPE PageHeightTwips;
        PITCHTYPE PageX;
        PITCHTYPE PageY;

        PITCHTYPE HorizontalPitchTwips;
        PITCHTYPE LineFeedPitchTwips;

        PITCHTYPE DpiToTwips(PITCHTYPE dpi);
        PITCHTYPE CpiToTwips(PITCHTYPE cpi);

        void SetCharacterSize(int horizontalDotsPerChar, int verticalDotsPerChar);
        void SetCpi(PITCHTYPE cpi);
        void SetDpi(PITCHTYPE dpi);
        void SetLpi(PITCHTYPE lpi);
        void SetLpiInDecitwips(PITCHTYPE decitwips);

        void AddX(int x);
        void CarriageReturn(bool lineFeed = false);
        bool LineFeed(bool carriageReturn = false);
        void NewPage();
        void PlotPixel(int offsetX, int offsetY);
        void PrintCharacter(unsigned char byte);
        void UpdateFontSize();
        void WrapX();

    private:
        bool CharacterIsAdjacent;
    };
}
