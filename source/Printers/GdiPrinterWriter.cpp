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
#include "GdiPrinterWriter.h"

namespace AncientPrinterEmulationLibrary
{
    GdiPrinterWriter::GdiPrinterWriter(LPCTSTR documentName, LPCTSTR fontName, int paperSize /* = DMPAPER_LETTER */)
    {
        m_DocumentName = documentName;
        m_FontName = fontName;
        m_PaperSize = paperSize;

        m_DotSize = 0;
        m_FontHeight = 0;
        m_FontWidth = 0;

        m_Font = NULL;
        m_PrinterDC = NULL;

        m_PageStarted = false;
        m_Ready = false;
    }

    GdiPrinterWriter::~GdiPrinterWriter()
    {
        Close();
    }

    void GdiPrinterWriter::Close()
    {
        if (m_Ready)
        {
            EndPage();
            ::EndDoc(m_PrinterDC);
            LogOutput("Doc Ended\n");
            if (m_PrinterDC)
            {
                ::DeleteDC(m_PrinterDC);
                m_PrinterDC = NULL;
            }
            DeleteFont();
            m_Ready = false;
        }
    }

    bool GdiPrinterWriter::CreatedFont()
    {
        if (m_Font)
            return true;

        if (m_FontWidth == 0 || m_FontHeight == 0)
            return false;

        m_Font = ::CreateFont(
            /* _In_ int     nHeight            */ (int)((m_FontHeight + 1) * m_ScaleY), // Fudge Factor +1 to make fonts a bit bigger
            /* _In_ int     nWidth             */ (int)((m_FontWidth + 1) * m_ScaleX), // Fudge Factor +1 to make fonts a bit bigger
            /* _In_ int     nEscapement        */ 0,
            /* _In_ int     nOrientation       */ 0,
            /* _In_ int     fnWeight           */ FW_NORMAL,
            /* _In_ DWORD   fdwItalic          */ false,
            /* _In_ DWORD   fdwUnderline       */ false,
            /* _In_ DWORD   fdwStrikeOut       */ false,
            /* _In_ DWORD   fdwCharSet         */ ANSI_CHARSET,
            /* _In_ DWORD   fdwOutputPrecision */ OUT_DEFAULT_PRECIS,
            /* _In_ DWORD   fdwClipPrecision   */ CLIP_DEFAULT_PRECIS,
            /* _In_ DWORD   fdwQuality         */ PROOF_QUALITY,
            /* _In_ DWORD   fdwPitchAndFamily  */ DEFAULT_PITCH | FF_DONTCARE,
            /* _In_ LPCTSTR lpszFace           */ m_FontName.c_str());

        ::SelectObject(m_PrinterDC, m_Font);
        ::SetTextColor(m_PrinterDC, RGB(0, 0, 0)); // Black
        ::SetBkColor(m_PrinterDC, RGB(0xFF, 0xFF, 0xFF)); // White
        ::SetBkMode(m_PrinterDC, TRANSPARENT);

        return m_Font != 0;
    }

    void GdiPrinterWriter::DeleteFont()
    {
        if (m_Font)
        {
            ::DeleteObject(m_Font);
            m_Font = NULL;
        }
    }

    void GdiPrinterWriter::EndPage()
    {
        if (m_PageStarted)
        {
            ::EndPage(m_PrinterDC);
            LogOutput("Page Ended\n");
            m_PageStarted = false;
        }
    }

    int GdiPrinterWriter::Plot(int x, int y)
    {
        if (!StartedPage())
            return 1;

        RECT r;
        r.left = (int)(x * m_ScaleX);
        r.top = (int)(y * m_ScaleY);
        r.right = (int)((x + m_DotSize) * m_ScaleX) + 1; // Fudge Factor +1! Reduce the visibility of vertical gaps.
        r.bottom = (int)((y + m_DotSize) * m_ScaleY) + 2; // Fudge Factor +2! Reduce the visibility of horizontal gaps.

        // TODO: Using FillRect to simulate adjacent plots results in gaps needing fudge factors above.
        // It might be a scaling error in GDI printing, since both PDF and XPS virtual printers show it.
        // Plotting to a bitmap then rendering that to the printer page might look better.

        return ::FillRect(
            /* _In_        HDC    hDC   */ m_PrinterDC,
            /* _In_  const RECT   *lprc */ &r,
            /* _In_        HBRUSH hbr   */ (HBRUSH)(GetStockObject(BLACK_BRUSH))) != 0;
    }

    int GdiPrinterWriter::SetFont(int textWidth, int textHeight)
    {
        if (m_FontWidth == textWidth && m_FontHeight == textHeight)
            return 0;

        m_FontWidth = textWidth;
        m_FontHeight = textHeight;

        DeleteFont();
        return 0;
    }

    void GdiPrinterWriter::SetupPage()
    {
        ::SetMapMode(m_PrinterDC, MM_TEXT); // MM_TEXT units are pixels - easier to use pixel fudge factors in Plot()

        LogOutput("Desired page width, height in twips = %d, %d\n", m_PageWidth, m_PageHeight);
        int width_in_mm = ::GetDeviceCaps(m_PrinterDC, HORZSIZE);
        int height_in_mm = ::GetDeviceCaps(m_PrinterDC, VERTSIZE);
        LogOutput("Device width, height in mm = %d, %d\n", width_in_mm, height_in_mm);

        const double twips_per_cm = 1440 / 2.54;
        int width_in_twips = (int)((width_in_mm * twips_per_cm) / 10);
        int height_in_twips = (int)((height_in_mm * twips_per_cm) / 10);
        LogOutput("Device width, height in twips = %d, %d\n", width_in_twips, height_in_twips);

        int width_in_pixels = ::GetDeviceCaps(m_PrinterDC, HORZRES);
        int height_in_pixels = ::GetDeviceCaps(m_PrinterDC, VERTRES);
        LogOutput("Device width, height in pixels = %d, %d\n", width_in_pixels, height_in_pixels);

        m_ScaleX = (double)width_in_pixels / width_in_twips;
        m_ScaleY = (double)height_in_pixels / height_in_twips;
    }

    int GdiPrinterWriter::SetPageMetrics(int pageWidth, int pageHeight, int dotSize)
    {
        m_DotSize = dotSize;
        m_PageHeight = pageHeight; // TODO: Not used - need to reconcile with user selected paper size
        m_PageWidth = pageWidth; // TODO: Not used - need to reconcile with user selected paper size

        return 0;
    }

    bool GdiPrinterWriter::StartedDoc()
    {
        if (m_Ready)
            return true;

        if (m_PrinterDC == NULL)
        {
            // Get the default printer DEVMODE
            PRINTDLG pd = {};
            pd.lStructSize = sizeof(pd);
            pd.Flags = PD_RETURNDEFAULT;
            PrintDlg(&pd);

            if (!pd.hDevMode)
                return false;

            // Assert out settings
            PDEVMODE dm = (PDEVMODE)GlobalLock(pd.hDevMode);
            if (dm)
            {
                dm->dmFields = dm->dmFields | DM_ORIENTATION | DM_PAPERSIZE;
                dm->dmOrientation = DMORIENT_PORTRAIT;
                dm->dmPaperSize = m_PaperSize;
                GlobalUnlock(pd.hDevMode);
            }

            // The user chooses a printer (starting with the default and our settings)
            pd.hwndOwner = GetForegroundWindow();
            pd.Flags = PD_RETURNDC | PD_USEDEVMODECOPIESANDCOLLATE;
            if (::PrintDlg(&pd) == 0)
                return false;

            m_PrinterDC = pd.hDC;

            // Start the document
            DOCINFO di{};
            di.cbSize = sizeof(DOCINFO);
            di.lpszDocName = m_DocumentName.c_str();
            if (::StartDoc(m_PrinterDC, &di) <= 0)
                return false;

            LogOutput("Doc Started\n");
            m_Ready = true;
        }
        return m_Ready;
    }

    bool GdiPrinterWriter::StartedPage()
    {
        if (!m_PageStarted)
        {
            if (!StartedDoc())
                return false;

            ::StartPage(m_PrinterDC);
            LogOutput("Page Started\n");
            SetupPage();

            m_PageStarted = true;
        }
        return m_PageStarted;
    }

    int GdiPrinterWriter::WriteCharacter(int x, int y, char character)
    {
        if (character < 0x20)
            return 0;

        if (!StartedPage())
            return 0;

        if (!CreatedFont())
            return 0;

        SIZE size;
        CHAR text[] = { character, '\0' };
        ::GetTextExtentPoint32(
            /* _In_  HDC     hdc      */ m_PrinterDC,
            /* _In_  LPCTSTR lpString */ &text[0],
            /* _In_  int     c        */ 1,
            /* _Out_ LPSIZE  lpSize   */ &size);

        int result = ::TextOut(
            /* _In_  HDC     hdc       */ m_PrinterDC,
            /* _In_  int     nXStart   */ (int)(x * m_ScaleX),
            /* _In_  int     nYStart   */ (int)(y * m_ScaleY),
            /* _In_  LPCTSTR lpString  */ &text[0],
            /* _In_  int     cchString */ 1);

        return (int)(size.cx / m_ScaleX);
    }
}
