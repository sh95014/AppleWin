//
//  MarianiFrame.h
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#pragma once

#include "sdlframe.h"

namespace common2
{
  struct EmulatorOptions;
}

namespace mariani
{

  class MarianiFrame : public sa2::SDLFrame
  {
  public:
    MarianiFrame(const common2::EmulatorOptions & options);

    void VideoPresentScreen() override;
    void Initialize(bool resetVideoState) override;

    void ProcessKeyDown(const SDL_KeyboardEvent & key);
    void ProcessText(const SDL_TextInputEvent & text);

    int FrameMessageBox(LPCSTR lpText, LPCSTR lpCaption, UINT uType) override;

    void FrameDrawDiskLEDS() override;
    void FrameRefreshStatus(int flags) override;

    virtual std::string Video_GetScreenShotFolder() const override;

    void *FrameBufferData();

  protected:
    void GetRelativeMousePosition(const SDL_MouseMotionEvent & motion, double & x, double & y) const override;

    virtual std::string getResourcePath(const std::string & filename) override;

  private:
    // FIXME: without this hack the app crashes randomly elsewhere
    Uint8 padding[1];
  };

}
