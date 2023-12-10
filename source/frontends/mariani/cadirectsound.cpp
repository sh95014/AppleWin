//
//  cadirectsound.cpp
//  Mariani
//
//  Created by sh95014 on 12/10/23.
//  Forked from frontends/sdl/sdirectsound.cpp
//

#include "frontends/sdl/sdirectsound.h"
#include "windows.h"
#include "Core.h"
#include <AudioToolbox/AudioToolbox.h>

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
    
    class DirectSoundGenerator : public IDirectSoundBuffer
    {
    public:
        DirectSoundGenerator(LPCDSBUFFERDESC lpcDSBufferDesc,
                             const char * deviceName,
                             const size_t ms);
        virtual HRESULT Release() override;
        
        void resetUnderruns();
        
        sa2::SoundInfo getInfo();
        
        friend OSStatus DirectSoundRenderProc(void * inRefCon,
                                              AudioUnitRenderActionFlags * ioActionFlags,
                                              const AudioTimeStamp * inTimeStamp,
                                              UInt32 inBusNumber,
                                              UInt32 inNumberFrames,
                                              AudioBufferList * ioData);
        void setVolumeIfNecessary();
        
    private:
        std::vector<uint8_t> myMixerBuffer;
        
        AudioUnit outputUnit;
        Float32 volume;
        
        size_t myBytesPerSecond;
    };
    
    std::unordered_map<DirectSoundGenerator *, std::shared_ptr<DirectSoundGenerator>> activeSoundGenerators;
    
    DirectSoundGenerator::DirectSoundGenerator(LPCDSBUFFERDESC lpcDSBufferDesc,
                                               const char * deviceName,
                                               const size_t ms)
        : IDirectSoundBuffer(lpcDSBufferDesc)
        , outputUnit(0)
        , volume(0)
        , myBytesPerSecond(0)
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
        
        setVolumeIfNecessary();
        
        if (AudioUnitInitialize(outputUnit) != noErr) {
            fprintf(stderr, "can't initialize output unit\n");
            return;
        }
        
        OSStatus status = AudioOutputUnitStart(outputUnit);
        fprintf(stderr, "output unit %p, status %d\n", outputUnit, status);
    }
    
    HRESULT DirectSoundGenerator::Release()
    {
        AudioOutputUnitStop(outputUnit);
        AudioUnitUninitialize(outputUnit);
        AudioComponentInstanceDispose(outputUnit);
        outputUnit = 0;
        return S_OK;
    }
    
    sa2::SoundInfo DirectSoundGenerator::getInfo()
    {
        DWORD dwStatus;
        GetStatus(&dwStatus);
        
        sa2::SoundInfo info;
        info.running = dwStatus & DSBSTATUS_PLAYING;
        info.channels = (UInt32)myChannels;
        info.volume = GetLogarithmicVolume();
        info.numberOfUnderruns = GetBufferUnderruns();
        
        if (info.running && myBytesPerSecond > 0)  {
            const DWORD bytesInBuffer = GetBytesInBuffer();
            const float coeff = 1.0 / myBytesPerSecond;
            info.buffer = bytesInBuffer * coeff;
            info.size = myBufferSize * coeff;
        }
        
        return info;
    }
    
    void DirectSoundGenerator::resetUnderruns()
    {
        ResetUnderrruns();
    }
    
    void DirectSoundGenerator::setVolumeIfNecessary()
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
            } else {
                fprintf(stderr, "can't set volume\n");
            }
        }
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
        if (lpvAudioPtr1 && dwAudioBytes1)
        {
            memcpy(data, lpvAudioPtr1, dwAudioBytes1);
        }
        // copy the second (wrapped-around) part of the ring buffer, if any
        if (lpvAudioPtr2 && dwAudioBytes2)
        {
            memcpy(data + dwAudioBytes1, lpvAudioPtr2, dwAudioBytes2);
        }
        // doesn't seem ever necessary, but fill the rest of the requested buffer with silence
        // if DirectSoundGenerator doesn't have enough
        if (size > dwAudioBytes1 + dwAudioBytes2)
        {
            memset(data + dwAudioBytes1 + dwAudioBytes2, 0, size - (dwAudioBytes1 + dwAudioBytes2));
        }

        dsg->setVolumeIfNecessary();

        return noErr;
    }

} // namespace

IDirectSoundBuffer * iCreateDirectSoundBuffer(LPCDSBUFFERDESC lpcDSBufferDesc)
{
    try
    {
        const char * deviceName = audioDeviceName.empty() ? nullptr : audioDeviceName.c_str();
        
        std::shared_ptr<DirectSoundGenerator> generator = std::make_shared<DirectSoundGenerator>(lpcDSBufferDesc, deviceName, audioBuffer);
        DirectSoundGenerator * ptr = generator.get();
        activeSoundGenerators[ptr] = generator;
        return ptr;
    }
    catch (const std::exception & e)
    {
        // once this fails, no point in trying again next time
        g_bDisableDirectSound = true;
        g_bDisableDirectSoundMockingboard = true;
        LogOutput("IDirectSoundBuffer: %s\n", e.what());
        return nullptr;
    }
}
