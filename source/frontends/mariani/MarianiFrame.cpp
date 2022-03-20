//
//  MarianiFrame.cpp
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#include "StdAfx.h"
#include "MarianiFrame.h"
#include "linux/resources.h"
#include "ParallelInterface.h"
#include "AppDelegate.h"

namespace mariani
{

  MarianiFrame::MarianiFrame(const common2::EmulatorOptions & options)
    : SDLFrame(options)
  {
    g_sProgramDir = GetSupportDirectory();
  }

  void MarianiFrame::Initialize(bool resetVideoState)
  {
    SDLFrame::Initialize(resetVideoState);
  }

  void MarianiFrame::VideoPresentScreen()
  {
  }

  void MarianiFrame::GetRelativeMousePosition(const SDL_MouseMotionEvent & motion, double & x, double & y) const
  {
  }

  void MarianiFrame::ProcessKeyDown(const SDL_KeyboardEvent & key)
  {
  }

  void MarianiFrame::ProcessText(const SDL_TextInputEvent & text)
  {
  }

  int MarianiFrame::FrameMessageBox(LPCSTR lpText, LPCSTR lpCaption, UINT uType)
  {
    int returnValue = ShowModalAlertOfType(uType, lpCaption, lpText);
    ResetSpeed();
    return returnValue;
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
