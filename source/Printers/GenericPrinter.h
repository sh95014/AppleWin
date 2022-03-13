//
//  GenericPrinter.h
//
//  AppleWin is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  AppleWin is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with AppleWin; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  Created by sh95014 on 3/12/22.
//

#pragma once
#include "Printer.h"

namespace AncientPrinterEmulationLibrary
{
	class GenericPrinter : public Printer
	{
	public:
		GenericPrinter(Writer& output) : Printer(output) {};
		virtual int Send(unsigned char byte) { return m_Output.WriteCharacter(0, 0, byte); };
	};
}
