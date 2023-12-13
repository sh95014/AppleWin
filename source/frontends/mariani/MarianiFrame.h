//
//  MarianiFrame.h
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#pragma once

#include "commonframe.h"
#include "Configuration/Config.h"

namespace mariani
{

  class MarianiFrame : public common2::CommonFrame
  {
  public:
    MarianiFrame(const common2::EmulatorOptions & options);

    void VideoPresentScreen() override;

    int FrameMessageBox(LPCSTR lpText, LPCSTR lpCaption, UINT uType) override;
    void GetBitmap(LPCSTR lpBitmapName, LONG cb, LPVOID lpvBits) override;

    void FrameDrawDiskLEDS() override;
    void FrameRefreshStatus(int flags) override;

    virtual std::string Video_GetScreenShotFolder() const override;

    void *FrameBufferData();

  protected:
    virtual std::string getResourcePath(const std::string & filename) override;
  };

}
