//
//  MarianiFrame.h
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#pragma once

#include "commonframe.h"
#include "Common.h"
#include "Configuration/Config.h"
#include "speed.h"

namespace common2
{
  struct EmulatorOptions;
}

namespace mariani
{

  class MarianiFrame : public common2::CommonFrame
  {
  public:
    MarianiFrame(const common2::EmulatorOptions & options);

    void Begin() override;

    void VideoPresentScreen() override;

    int FrameMessageBox(LPCSTR lpText, LPCSTR lpCaption, UINT uType) override;
    void GetBitmap(LPCSTR lpBitmapName, LONG cb, LPVOID lpvBits) override;

    void FrameDrawDiskLEDS() override;
    void FrameRefreshStatus(int flags) override;

    virtual std::string Video_GetScreenShotFolder() const override;

    void *FrameBufferData();

    void ResetSpeed();
    void SetFullSpeed(const bool value);
    bool CanDoFullSpeed();

    void ExecuteOneFrame(const uint64_t microseconds);

    void ChangeMode(const AppMode_e mode);
    void SingleStep();

    void ResetHardware();
    bool HardwareChanged() const;

  protected:
    virtual std::string getResourcePath(const std::string & filename) override;

    void ExecuteInRunningMode(const uint64_t microseconds);
    void ExecuteInDebugMode(const uint64_t microseconds);
    void Execute(const DWORD uCycles);

  private:
    common2::Speed mySpeed;
    CConfigNeedingRestart myHardwareConfig;
  };

}
