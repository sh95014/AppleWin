//
//  cadirectsound.cpp
//  Mariani
//
//  Created by sh95014 on 12/10/23.
//  Forked from frontends/sdl/sdirectsound.cpp
//

#include <unordered_set>
#include <AudioToolbox/AudioToolbox.h>
#include "windows.h"
#include "linux/linuxsoundbuffer.h"
#include "Core.h"
#include "AppDelegate.h"
#include "cadirectsound.h"

namespace
{
    // these have to come from EmulatorOptions
    std::string audioDeviceName;
    size_t audioBuffer = 0;
    
    OSStatus DirectSoundRenderProc(void * inRefCon,
                                   AudioUnitRenderActionFlags * ioActionFlags,
                                   const AudioTimeStamp * inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList * ioData);
    
    class DirectSoundGenerator : public LinuxSoundBuffer
    {
    public:
        DirectSoundGenerator(DWORD dwBufferSize,
                             DWORD nSampleRate,
                             int nChannels,
                             LPCSTR pStreamName);
        virtual ~DirectSoundGenerator() override;
        
        virtual HRESULT Unlock(LPVOID lpvAudioPtr1,
                               DWORD dwAudioBytes1,
                               LPVOID lpvAudioPtr2,
                               DWORD dwAudioBytes2) override;
        
        friend OSStatus DirectSoundRenderProc(void * inRefCon,
                                              AudioUnitRenderActionFlags * ioActionFlags,
                                              const AudioTimeStamp * inTimeStamp,
                                              UInt32 inBusNumber,
                                              UInt32 inNumberFrames,
                                              AudioBufferList * ioData);
        
        void SetVolumeIfNecessary();
        
        void SetAudioOutput(int inAudioOutput);
        
    private:
        AudioUnit outputUnit;
        Float32 volume;
        int audioOutput;
    };
    
    std::unordered_set<DirectSoundGenerator *> activeSoundGenerators;
    
    DirectSoundGenerator::DirectSoundGenerator(DWORD dwBufferSize,
                                               DWORD nSampleRate,
                                               int nChannels,
                                               LPCSTR pStreamName)
        : LinuxSoundBuffer(dwBufferSize, nSampleRate, nChannels, pStreamName)
        , outputUnit(0)
        , volume(0)
        , audioOutput(-1)
    {
        AudioComponentDescription desc = { 0 };
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_DefaultOutput;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        if (comp == NULL) {
            fprintf(stderr, "can't find audio component\n");
            return;
        }
        
        if (AudioComponentInstanceNew(comp, &outputUnit) != noErr) {
            fprintf(stderr, "can't create output unit\n");
            return;
        }
        
        AudioStreamBasicDescription absd = { 0 };
        absd.mSampleRate = mySampleRate;
        absd.mFormatID = kAudioFormatLinearPCM;
        absd.mFormatFlags = kAudioFormatFlagIsSignedInteger;
        absd.mFramesPerPacket = 1;
        absd.mChannelsPerFrame = (UInt32)myChannels;
        absd.mBitsPerChannel = sizeof(SInt16) * CHAR_BIT;
        absd.mBytesPerPacket = sizeof(SInt16) * (UInt32)myChannels;
        absd.mBytesPerFrame = sizeof(SInt16) * (UInt32)myChannels;
        if (AudioUnitSetProperty(outputUnit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input,
                                 0,
                                 &absd,
                                 sizeof(absd))) {
            fprintf(stderr, "can't set stream format\n");
            return;
        }
        
        AURenderCallbackStruct input;
        input.inputProc = DirectSoundRenderProc;
        input.inputProcRefCon = this;
        if (AudioUnitSetProperty(outputUnit,
                                 kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input,
                                 0,
                                 &input,
                                 sizeof(input)) != noErr) {
            fprintf(stderr, "can't set callback property\n");
            return;
        }
        
        SetVolumeIfNecessary();
        
        if (AudioUnitInitialize(outputUnit) != noErr) {
            fprintf(stderr, "can't initialize output unit\n");
            return;
        }
        
        OSStatus status = AudioOutputUnitStart(outputUnit);
        fprintf(stderr, "output unit %p, status %d\n", outputUnit, status);
    }
    
    DirectSoundGenerator::~DirectSoundGenerator()
    {
        activeSoundGenerators.erase(this);
        AudioOutputUnitStop(outputUnit);
        AudioUnitUninitialize(outputUnit);
        AudioComponentInstanceDispose(outputUnit);
        outputUnit = 0;
    }
    
    HRESULT DirectSoundGenerator::Unlock(LPVOID lpvAudioPtr1,
                                         DWORD dwAudioBytes1,
                                         LPVOID lpvAudioPtr2,
                                         DWORD dwAudioBytes2)
    {
        // send audio to be optionally recorded
        if (dwAudioBytes1 + dwAudioBytes2) {
            SubmitAudio(this->audioOutput, lpvAudioPtr1, dwAudioBytes1, lpvAudioPtr2, dwAudioBytes2);
        }
        return LinuxSoundBuffer::Unlock(lpvAudioPtr1, dwAudioBytes1, lpvAudioPtr2, dwAudioBytes2);
    }
    
    void DirectSoundGenerator::SetVolumeIfNecessary()
    {
        const double logVolume = GetLogarithmicVolume();
        // same formula as QAudio::convertVolume()
        const Float32 linVolume = logVolume > 0.99 ? 1.0 : -std::log(1.0 - logVolume) / std::log(100.0);
        if (fabs(linVolume - volume) > FLT_EPSILON) {
            if (AudioUnitSetParameter(outputUnit,
                                      kHALOutputParam_Volume,
                                      kAudioUnitScope_Global,
                                      0,
                                      linVolume,
                                      0) == noErr) {
                volume = linVolume;
            }
            else {
                fprintf(stderr, "can't set volume\n");
            }
        }
    }
    
    void DirectSoundGenerator::SetAudioOutput(int inAudioOutput) {
        audioOutput = inAudioOutput;
    }
    
    OSStatus DirectSoundRenderProc(void * inRefCon,
                                   AudioUnitRenderActionFlags * ioActionFlags,
                                   const AudioTimeStamp * inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList * ioData)
    {
        DirectSoundGenerator *dsg = (DirectSoundGenerator *)inRefCon;
        UInt8 * data = (UInt8 *)ioData->mBuffers[0].mData;
        
        DWORD size = (DWORD)(inNumberFrames * dsg->myChannels * sizeof(SInt16));
        
        LPVOID lpvAudioPtr1, lpvAudioPtr2;
        DWORD dwAudioBytes1, dwAudioBytes2;
        dsg->Read(size, &lpvAudioPtr1, &dwAudioBytes1, &lpvAudioPtr2, &dwAudioBytes2);
        
        // copy the first part from the ring buffer
        if (lpvAudioPtr1 && dwAudioBytes1) {
            memcpy(data, lpvAudioPtr1, dwAudioBytes1);
        }
        // copy the second (wrapped-around) part of the ring buffer, if any
        if (lpvAudioPtr2 && dwAudioBytes2) {
            memcpy(data + dwAudioBytes1, lpvAudioPtr2, dwAudioBytes2);
        }
        // doesn't seem ever necessary, but fill the rest of the requested buffer with silence
        // if DirectSoundGenerator doesn't have enough
        if (size > dwAudioBytes1 + dwAudioBytes2) {
            memset(data + dwAudioBytes1 + dwAudioBytes2, 0, size - (dwAudioBytes1 + dwAudioBytes2));
        }
        
        dsg->SetVolumeIfNecessary();
        
        return noErr;
    }

} // namespace

std::shared_ptr<SoundBuffer> iCreateDirectSoundBuffer(
    uint32_t dwBufferSize, uint32_t nSampleRate, int nChannels, const char *pszVoiceName)
{
    try {
        std::shared_ptr<DirectSoundGenerator> generator = std::make_shared<DirectSoundGenerator>(dwBufferSize, nSampleRate, nChannels, pszVoiceName);
        DirectSoundGenerator * ptr = generator.get();
        activeSoundGenerators.insert(ptr);
        ptr->SetAudioOutput(RegisterAudioOutput(ptr->myChannels, ptr->mySampleRate));
        return generator;
    }
    catch (const std::exception & e) {
        // once this fails, no point in trying again next time
        g_bDisableDirectSound = true;
        g_bDisableDirectSoundMockingboard = true;
        LogOutput("DirectSoundGenerator: %s\n", e.what());
        return nullptr;
    }
}
