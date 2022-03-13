/*
AppleWin : An Apple //e emulator for Windows

Copyright (C) 1994-1996, Michael O'Brien
Copyright (C) 1999-2001, Oliver Schmidt
Copyright (C) 2002-2005, Tom Charlesworth
Copyright (C) 2006-2007, Tom Charlesworth, Michael Pohoreski, Nick Westgate

AppleWin is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

AppleWin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AppleWin; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/* Description: Parallel Printer Interface Card emulation
 *
 * Author: Nick Westgate, Stannev
 */

#include "StdAfx.h"

#include "ParallelInterface.h"
#include "Memory.h"
#include "YamlHelper.h"
#include "Interface.h"

#include "../resource/resource.h"

bool g_bDumpToPrinter = false;
bool g_bConvertEncoding = true;
bool g_bFilterUnprintable = true;
bool g_bPrinterAppend = false;
bool g_bEnableDumpToRealPrinter = false;
static AncientPrinterEmulationLibrary::Printer* g_printer = 0;

DWORD const PRINTDRVR_SIZE = APPLE_SLOT_SIZE;

//===========================================================================

static BYTE __stdcall PrintStatus(WORD, WORD, BYTE, BYTE, ULONG);
static BYTE __stdcall PrintTransmit(WORD, WORD, BYTE, BYTE value, ULONG);




VOID PrintLoadRom(LPBYTE pCxRomPeripheral, const UINT uSlot)
{
	BYTE* pData = GetFrame().GetResource(IDR_PRINTDRVR_FW, "FIRMWARE", PRINTDRVR_SIZE);
	if(pData == NULL)
		return;

	memcpy(pCxRomPeripheral + uSlot*256, pData, PRINTDRVR_SIZE);

	//

	RegisterIoHandler(uSlot, PrintStatus, PrintTransmit, NULL, NULL, NULL, NULL);
}

//===========================================================================
static void ClosePrint()
{
	if (g_printer)
	{
		g_printer->Close();
	}
}

//===========================================================================
void PrintDestroy()
{
    ClosePrint();
}

//===========================================================================
void PrintUpdate(DWORD totalcycles)
{
}

//===========================================================================
void PrintReset()
{
    ClosePrint();
}

//===========================================================================
static BYTE __stdcall PrintStatus(WORD, WORD, BYTE, BYTE, ULONG)
{
    return 0xFF; // status - TODO?
}

//===========================================================================
static BYTE __stdcall PrintTransmit(WORD, WORD address, BYTE, BYTE value, ULONG)
{
	// only allow writes to the load output port (i.e., $C090)
	if ((address & 0xF) != 0)
		return 0;

	BYTE c = value & 0x7F;

	if (g_printer)
	{
		g_printer->Send(c);
	}

	return 0;
}

//===========================================================================

const std::string & Printer_GetFilename()
{
	static const std::string empty = "";
	return empty;
}

void Printer_SetFilename(const std::string & prtFilename)
{
}

unsigned int Printer_GetIdleLimit()
{
	return 0;
}

void Printer_SetIdleLimit(unsigned int Duration)
{	
}

void Printer_SetPrinter(AncientPrinterEmulationLibrary::Printer & printer)
{
	g_printer = &printer;
}

//===========================================================================

#define SS_YAML_VALUE_CARD_PRINTER "Generic Printer"

const std::string& Printer_GetSnapshotCardName(void)
{
	static const std::string name(SS_YAML_VALUE_CARD_PRINTER);
	return name;
}

void Printer_SaveSnapshot(class YamlSaveHelper& yamlSaveHelper, const UINT uSlot)
{
}

bool Printer_LoadSnapshot(class YamlLoadHelper& yamlLoadHelper, UINT slot, UINT version)
{
	return true;
}
