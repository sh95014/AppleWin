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
#include <string>
#include "BasePrinter.h"

namespace AncientPrinterEmulationLibrary
{
    class AppleWriterPrinter : public BasePrinter
    {
    public:
        AppleWriterPrinter(Writer& output);

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

        void ConsumeData();
        void ExpectArg(int length);
        void ExpectData(int length);
        void ExpectText();
        int  GetArgInt();
        void HandleData(unsigned char byte);
        void HandleText(unsigned char byte);
        void PlotGraphics(unsigned char byte);

        std::string   m_Arg;
        unsigned int  m_ArgLengthExpected;
        int           m_DataLength;
        int           m_DataLengthExpected;
        unsigned char m_Code;
        Mode          m_Mode;
    };
}