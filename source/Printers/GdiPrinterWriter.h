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
#include <windows.h>
#include <string>

#include "Writer.h"

namespace AncientPrinterEmulationLibrary
{
    class GdiPrinterWriter : public Writer
    {
    public:
        GdiPrinterWriter(LPCTSTR documentName, LPCTSTR fontName, int paperSize = DMPAPER_LETTER);
        virtual ~GdiPrinterWriter();

        virtual void Close();
        virtual void EndPage();
        virtual int Plot(int x, int y);
        virtual int SetFont(int textWidth, int textHeight);
        virtual int SetPageMetrics(int pageWidth, int pageHeight, int dotSize);
        virtual int WriteCharacter(int x, int y, char character);

    protected:
        std::string m_DocumentName;
        int         m_DotSize;
        HFONT       m_Font;
        int         m_FontHeight;
        int         m_FontWidth;
        std::string m_FontName;
        int         m_PageHeight;
        bool        m_PageStarted;
        int         m_PageWidth;
        int         m_PaperSize;
        HDC         m_PrinterDC;
        bool        m_Ready;
        double      m_ScaleX;
        double      m_ScaleY;

        bool CreatedFont();
        void DeleteFont();
        void SetupPage();
        bool StartedDoc();
        bool StartedPage();
    };
}
