//
//  MarianiFrame.cpp
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#include "StdAfx.h"
#include "MarianiFrame.h"
#include "resource.h"
#include "programoptions.h"

#include <sys/stat.h>

#include "CPU.h"
#include "CardManager.h"
#include "Core.h"
#include "Debug.h"
#include "NTSC.h"
#include "ParallelPrinter.h"
#include "Speaker.h"

#include "AppDelegate.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include "cadirectsound.h"

namespace mariani {

MarianiFrame::MarianiFrame(const common2::EmulatorOptions& options)
    : CommonFrame(options)
    , roms()
{
    g_sProgramDir = GetSupportDirectory();
    g_sBuiltinSymbolsDir = GetBuiltinSymbolsDirectory();
}

int MarianiFrame::FrameMessageBox(LPCSTR lpText, LPCSTR lpCaption, UINT uType)
{
    int returnValue = ShowModalAlertOfType(uType, lpCaption, lpText);
    ResetSpeed();
    return returnValue;
}

void MarianiFrame::GetBitmap(WORD id, LONG cb, LPVOID lpvBits)
{
    // reads a monochrome BMP file, then combines eight pixels into an octet
    // and writes it to lpvBits

    const char *path = NULL;
    switch (id) {
        case IDB_CHARSET82: path = PathToResourceNamed("CHARSET82.bmp"); break;
        case IDB_CHARSET8C: path = PathToResourceNamed("CHARSET8C.bmp"); break;
        case IDB_CHARSET8M: path = PathToResourceNamed("CHARSET8M.bmp"); break;
        default:
            ShowModalAlertOfType(MB_ICONSTOP, "Unrecognized bitmap resource", std::to_string(id).c_str());
            return;
    }

    const CFStringRef cfPath = CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
    const CFURLRef imageURL = CFURLCreateWithFileSystemPath(NULL, cfPath, kCFURLPOSIXPathStyle, false);
    const CGImageSourceRef imageSource = CGImageSourceCreateWithURL(imageURL, NULL);
    const CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    const CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(image));

    assert(rawData != NULL);

    const UInt8* source = CFDataGetBytePtr(rawData);
    const size_t size = CGImageGetHeight(image) * CGImageGetWidth(image) / 8;
    const size_t requested = cb;

    const size_t copied = std::min(requested, size);

    char* dest = static_cast<char*>(lpvBits);

    for (size_t i = 0; i < copied; ++i) {
        const size_t offset = i * 8;
        char val = 0;
        for (size_t j = 0; j < 8; ++j) {
            const char pixel = *(source + offset + j);
            val = (val << 1) | (pixel != 0);
        }
        dest[i] = val;
    }

    if (rawData) {
        CFRelease(rawData);
    }
    if (image) {
        CFRelease(image);
    }
    if (imageSource) {
        CFRelease(imageSource);
    }
    if (imageURL) {
        CFRelease(imageURL);
    }
    if (cfPath) {
        CFRelease(cfPath);
    }
}

void MarianiFrame::FrameDrawDiskLEDS()
{
    UpdateDriveLights();
}

void MarianiFrame::FrameRefreshStatus(int flags)
{
    if (flags & (DRAW_LEDS | DRAW_DISK_STATUS)) {
        UpdateDriveLights();
    }
}

void* MarianiFrame::FrameBufferData()
{
    return myFramebuffer.data();
}

std::shared_ptr<SoundBuffer> MarianiFrame::CreateSoundBuffer(uint32_t dwBufferSize, uint32_t nSampleRate, int nChannels, const char *pszVoiceName)
{
    return iCreateDirectSoundBuffer(dwBufferSize, nSampleRate, nChannels, pszVoiceName);
}

std::pair<const unsigned char *, unsigned int> MarianiFrame::GetResourceData(WORD id) const {
    auto it{roms.find(id)};
    if (it != roms.end()) {
        return std::pair(it->second.data(), it->second.size());
    }
    
    const char *path = NULL;
    switch (id) {
        case IDR_DISK2_13SECTOR_FW: path = PathToResourceNamed("DISK2-13sector.rom"); break;
        case IDR_DISK2_16SECTOR_FW: path = PathToResourceNamed("DISK2.rom"); break;
        case IDR_SSC_FW: path = PathToResourceNamed("SSC.rom"); break;
        case IDR_HDDRVR_FW: path = PathToResourceNamed("Hddrvr.bin"); break;
        case IDR_HDDRVR_V2_FW: path = PathToResourceNamed("Hddrvr-v2.bin"); break;
        case IDR_HDC_SMARTPORT_FW: path = PathToResourceNamed("HDC-SmartPort.bin"); break;
        case IDR_PRINTDRVR_FW: path = PathToResourceNamed("Parallel.rom"); break;
        case IDR_MOCKINGBOARD_D_FW: path = PathToResourceNamed("Mockingboard-D.rom"); break;
        case IDR_MOUSEINTERFACE_FW: path = PathToResourceNamed("MouseInterface.rom"); break;
        case IDR_THUNDERCLOCKPLUS_FW: path = PathToResourceNamed("ThunderClockPlus.rom"); break;
        case IDR_TKCLOCK_FW: path = PathToResourceNamed("TKClock.rom"); break;
        
        case IDR_APPLE2_ROM: path = PathToResourceNamed("Apple2.rom"); break;
        case IDR_APPLE2_PLUS_ROM: path = PathToResourceNamed("Apple2_Plus.rom"); break;
        case IDR_APPLE2_JPLUS_ROM: path = PathToResourceNamed("Apple2_JPlus.rom"); break;
        case IDR_APPLE2E_ROM: path = PathToResourceNamed("Apple2e.rom"); break;
        case IDR_APPLE2E_ENHANCED_ROM: path = PathToResourceNamed("Apple2e_Enhanced.rom"); break;
        case IDR_PRAVETS_82_ROM: path = PathToResourceNamed("PRAVETS82.ROM"); break;
        case IDR_PRAVETS_8M_ROM: path = PathToResourceNamed("PRAVETS8M.ROM"); break;
        case IDR_PRAVETS_8C_ROM: path = PathToResourceNamed("PRAVETS8C.ROM"); break;
        case IDR_TK3000_2E_ROM: path = PathToResourceNamed("TK3000e.rom"); break;
        case IDR_BASE_64A_ROM: path = PathToResourceNamed("Base64A.rom"); break;
        case IDR_FREEZES_F8_ROM: path = PathToResourceNamed("Freezes_Non-autostart_F8_Rom.rom"); break;
        
        case IDR_APPLE2_VIDEO_ROM: path = PathToResourceNamed("Apple2_Video.rom"); break;
        case IDR_APPLE2_JPLUS_VIDEO_ROM: path = PathToResourceNamed("Apple2_JPlus_Video.rom"); break;
        case IDR_APPLE2E_ENHANCED_VIDEO_ROM: path = PathToResourceNamed("Apple2e_Enhanced_Video.rom"); break;
        case IDR_BASE64A_VIDEO_ROM: path = PathToResourceNamed("Base64A_German_Video.rom"); break;
        default:
            ShowModalAlertOfType(MB_ICONSTOP, "Unrecognized resource", std::to_string(id).c_str());
            return std::pair((const unsigned char *)NULL, 0);
    }
    
    // open and read the resource file into memory
    // (adapted from the old CommonFrame::GetResource())
    const int fd = open(path, O_RDONLY);
    if (fd != -1)
    {
        std::pair<RomMap::iterator, bool> p;
        off_t size = 0;
        struct stat stdbuf;
        if ((fstat(fd, &stdbuf) == 0) && S_ISREG(stdbuf.st_mode))
        {
            size = stdbuf.st_size;
            std::vector<unsigned char> v(size);
            read(fd, v.data(), size);
            p = roms.insert_or_assign(id, v);
        }
        close(fd);
        // p's 'first' is the RomMap iterator, and the iterator's 'second' is the vector
        return std::pair(p.first->second.data(), p.first->second.size());
    }
    else
    {
        ShowModalAlertOfType(MB_ICONSTOP, "Resource not found", path);
        return std::pair((const unsigned char *)NULL, 0);
    }
}

}
