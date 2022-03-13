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
#include "TextFileWriter.h"

namespace AncientPrinterEmulationLibrary
{
    TextFileWriter::TextFileWriter(std::ostream& outputStream)
        :
        m_OutputStream(outputStream) // Parameter so caller handles opening errors
    {
    }

    TextFileWriter::~TextFileWriter()
    {
        m_OutputStream.flush();
    }

    void TextFileWriter::EndPage()
    {
        m_OutputStream.flush();
    }

    int TextFileWriter::WriteCharacter(int x, int y, char character)
    {
        // Filter most control characters - TODO: Add more?
        if (character >= 0x20
            || character == '\t'
			|| character == '\r'
            || character == '\n')
        {
            m_OutputStream.put(character);
        }
        if (character == '\n')
        {
            m_OutputStream.flush();
        }
        return 0;
    }
}
