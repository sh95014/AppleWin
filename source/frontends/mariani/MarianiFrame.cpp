//
//  MarianiFrame.cpp
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#include "StdAfx.h"
#include "MarianiFrame.h"
#include "linux/resources.h"
#include "AppDelegate.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>


namespace mariani
{

  MarianiFrame::MarianiFrame(const common2::EmulatorOptions & options)
    : SDLFrame(options)
  {
    g_sProgramDir = GetSupportDirectory();
    g_sBuiltinSymbolsDir = GetBuiltinSymbolsDirectory();
  }

  void MarianiFrame::Initialize(bool resetVideoState)
  {
    SDLFrame::Initialize(resetVideoState);
  }

  void MarianiFrame::VideoPresentScreen()
  {
  }

  int MarianiFrame::FrameMessageBox(LPCSTR lpText, LPCSTR lpCaption, UINT uType)
  {
    int returnValue = ShowModalAlertOfType(uType, lpCaption, lpText);
    ResetSpeed();
    return returnValue;
  }

  void MarianiFrame::GetBitmap(LPCSTR lpBitmapName, LONG cb, LPVOID lpvBits)
  {
    // reads a monochrome BMP file, then combines eight pixels into an octet
    // and writes it to lpvBits
    
    const std::string filename = getBitmapFilename(lpBitmapName);
    const std::string path = getResourcePath(filename);
    const CFStringRef cfPath = CFStringCreateWithCString(NULL, path.c_str(), kCFStringEncodingUTF8);
    const CFURLRef imageURL = CFURLCreateWithFileSystemPath(NULL, cfPath, kCFURLPOSIXPathStyle, false);
    const CGImageSourceRef imageSource = CGImageSourceCreateWithURL(imageURL, NULL);
    const CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    const CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(image));
    
    assert(rawData != NULL);
    
    const UInt8 * source = CFDataGetBytePtr(rawData);
    const size_t size = CGImageGetHeight(image) * CGImageGetWidth(image) / 8;
    const size_t requested = cb;
    
    const size_t copied = std::min(requested, size);
    
    char * dest = static_cast<char *>(lpvBits);
    
    for (size_t i = 0; i < copied; ++i)
    {
      const size_t offset = i * 8;
      char val = 0;
      for (size_t j = 0; j < 8; ++j)
      {
        const char pixel = *(source + offset + j);
        val = (val << 1) | (pixel != 0);
      }
      dest[i] = val;
    }
    
    if (rawData) { CFRelease(rawData); }
    if (image) { CFRelease(image); }
    if (imageSource) { CFRelease(imageSource); }
    if (imageURL) { CFRelease(imageURL); }
    if (cfPath) { CFRelease(cfPath); }
  }

  void MarianiFrame::FrameDrawDiskLEDS()
  {
    UpdateDriveLights();
  }

  void MarianiFrame::FrameRefreshStatus(int flags) {
    if (flags & (DRAW_LEDS | DRAW_DISK_STATUS)) {
      UpdateDriveLights();
    }
  }

  void *MarianiFrame::FrameBufferData() {
    return myFramebuffer.data();
  }

  std::string MarianiFrame::getResourcePath(const std::string & filename)
  {
    return std::string(PathToResourceNamed(filename.c_str()));
  }

  std::string MarianiFrame::Video_GetScreenShotFolder() const
  {
    return {};
  }

}
