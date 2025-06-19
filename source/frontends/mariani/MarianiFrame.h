//
//  MarianiFrame.h
//  Mariani
//
//  Created by sh95014 on 1/2/22.
//

#pragma once

#include "Configuration/Config.h"
#include "commonframe.h"
#include <map>

namespace mariani {

class MarianiFrame : public common2::CommonFrame {
public:
    MarianiFrame(const common2::EmulatorOptions& options);

    void VideoPresentScreen() override {}

    int FrameMessageBox(LPCSTR lpText, LPCSTR lpCaption, UINT uType) override;
    virtual void GetBitmap(WORD id, LONG cb, LPVOID lpvBits) override;

    void FrameDrawDiskLEDS() override;
    void FrameRefreshStatus(int flags) override;

    virtual std::string Video_GetScreenShotFolder() const override { return {}; }

    void* FrameBufferData();

    virtual std::shared_ptr<SoundBuffer> CreateSoundBuffer(uint32_t dwBufferSize, uint32_t nSampleRate, int nChannels, const char *pszVoiceName) override;

    const std::string& SnapshotPathname();
    void SetSnapshotPathname(std::string path);
    void SaveSnapshot();
    void LoadSnapshot(std::string path);

protected:
    virtual std::pair<const unsigned char *, unsigned int> GetResourceData(WORD id) const override;

private:
    typedef std::map<unsigned int, std::vector<unsigned char>> RomMap;
    mutable RomMap roms;
    
    // FIXME: without this hack the app crashes randomly elsewhere
    unsigned char padding[1];
};

}
