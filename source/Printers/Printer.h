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
#include "Writer.h"

namespace AncientPrinterEmulationLibrary
{
    class Printer
    {
    public:
        Printer(Writer& output) : m_Output(output) {};
        virtual ~Printer() { Close(); };

        virtual std::string Name() = 0;

        virtual void Close() { m_Output.Close(); };
        virtual int  Send(unsigned char byte) = 0;

    protected:
        Writer& m_Output;

    private:
        Printer(Printer const&);
    };
}
