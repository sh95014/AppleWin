//
//  cadirectsound..h
//  Mariani
//
//  Created by sh95014 on 5/31/25.
//

#ifndef CADIRECTSOUND_H
#define CADIRECTSOUND_H

#include "windows.h"
#include "linux/linuxsoundbuffer.h"

std::shared_ptr<SoundBuffer> iCreateDirectSoundBuffer(uint32_t dwBufferSize,
                                                      uint32_t nSampleRate,
                                                      int nChannels,
                                                      const char *pszVoiceName);

#endif /* CADIRECTSOUND_H */
