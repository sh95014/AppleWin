//
//  MarianiFrame.cpp
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#include "StdAfx.h"
#include "MarianiFrame.h"
#include "linux/resources.h"
#include "programoptions.h"

#include "CardManager.h"
#include "Core.h"
#include "CPU.h"
#include "Debug.h"
#include "NTSC.h"
#include "ParallelPrinter.h"
#include "Speaker.h"

#include "AppDelegate.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>


namespace mariani
{

  MarianiFrame::MarianiFrame(const common2::EmulatorOptions & options)
    : CommonFrame()
    , mySpeed(options.fixedSpeed)
  {
    g_sProgramDir = GetSupportDirectory();
    g_sBuiltinSymbolsDir = GetBuiltinSymbolsDirectory();
  }

  void MarianiFrame::Begin()
  {
    CommonFrame::Begin();
    mySpeed.reset();
    ResetHardware();
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

  void MarianiFrame::Execute(const DWORD cyclesToExecute)
  {
    const bool bVideoUpdate = !g_bFullSpeed;
    const UINT dwClksPerFrame = NTSC_GetCyclesPerFrame();
    
    // do it in the same batches as AppleWin (1 ms)
    const DWORD fExecutionPeriodClks = g_fCurrentCLK6502 * (1.0 / 1000.0);  // 1 ms
    
    DWORD totalCyclesExecuted = 0;
    // check at the end because we want to always execute at least 1 cycle even for "0"
    do
    {
      _ASSERT(cyclesToExecute >= totalCyclesExecuted);
      const DWORD thisCyclesToExecute = std::min(fExecutionPeriodClks, cyclesToExecute - totalCyclesExecuted);
      const DWORD executedCycles = CpuExecute(thisCyclesToExecute, bVideoUpdate);
      totalCyclesExecuted += executedCycles;
      
      GetCardMgr().Update(executedCycles);
      SpkrUpdate(executedCycles);
      
      g_dwCyclesThisFrame = (g_dwCyclesThisFrame + executedCycles) % dwClksPerFrame;
    } while (totalCyclesExecuted < cyclesToExecute);
  }

  void MarianiFrame::ExecuteInRunningMode(const uint64_t microseconds)
  {
    SetFullSpeed(CanDoFullSpeed());
    const DWORD cyclesToExecute = mySpeed.getCyclesTillNext(microseconds);  // this checks g_bFullSpeed
    Execute(cyclesToExecute);
  }

  void MarianiFrame::ExecuteInDebugMode(const uint64_t microseconds)
  {
    // In AppleWin this is called without a timer for just one iteration
    // because we run a "frame" at a time, we need a bit of ingenuity
    const DWORD cyclesToExecute = mySpeed.getCyclesAtFixedSpeed(microseconds);
    const uint64_t target = g_nCumulativeCycles + cyclesToExecute;
    
    while (g_nAppMode == MODE_STEPPING && g_nCumulativeCycles < target)
    {
      DebugContinueStepping();
    }
  }

  void MarianiFrame::ExecuteOneFrame(const uint64_t microseconds)
  {
    // when running in adaptive speed
    // the value msNextFrame is only a hint for when the next frame will arrive
    switch (g_nAppMode)
    {
    case MODE_RUNNING:
      ExecuteInRunningMode(microseconds);
      break;
    case MODE_STEPPING:
      ExecuteInDebugMode(microseconds);
      break;
    default:
      break;
    };
  }

  void MarianiFrame::ChangeMode(const AppMode_e mode)
  {
    if (mode != g_nAppMode)
    {
      switch (mode)
      {
      case MODE_RUNNING:
        DebugExitDebugger();
        SoundCore_SetFade(FADE_IN);
        break;
      case MODE_DEBUG:
        DebugBegin();
        CmdWindowViewConsole(0);
        break;
      default:
        g_nAppMode = mode;
        SoundCore_SetFade(FADE_OUT);
        break;
      }
      FrameRefreshStatus(DRAW_TITLE);
      ResetSpeed();
    }
  }

  void MarianiFrame::ResetSpeed()
  {
    mySpeed.reset();
  }

  void MarianiFrame::SetFullSpeed(const bool value)
  {
    if (g_bFullSpeed != value) {
      if (value)
      {
        // entering full speed
        GetCardMgr().GetMockingboardCardMgr().MuteControl(true);
        VideoRedrawScreenDuringFullSpeed(0, true);
      }
      else
      {
        // leaving full speed
        GetCardMgr().GetMockingboardCardMgr().MuteControl(false);
        mySpeed.reset();
      }
      g_bFullSpeed = value;
      g_nCpuCyclesFeedback = 0;
    }
  }

  bool MarianiFrame::CanDoFullSpeed()
  {
    return (g_dwSpeed == SPEED_MAX) ||
           (GetCardMgr().GetDisk2CardMgr().IsConditionForFullSpeed() && !Spkr_IsActive() && !GetCardMgr().GetMockingboardCardMgr().IsActive()) ||
           IsDebugSteppingAtFullSpeed();
  }

  void MarianiFrame::SingleStep()
  {
    SetFullSpeed(CanDoFullSpeed());
    Execute(0);
  }

  void MarianiFrame::ResetHardware()
  {
    myHardwareConfig.Reload();
  }

  bool MarianiFrame::HardwareChanged() const
  {
    const CConfigNeedingRestart currentConfig = CConfigNeedingRestart::Create();
    return myHardwareConfig != currentConfig;
  }

}
