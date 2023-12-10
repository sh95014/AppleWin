#include "StdAfx.h"
#include "frontends/sdl/sdirectsound.h"
#include "frontends/sdl/utils.h"
#include "frontends/common2/programoptions.h"

#include "windows.h"
#include "linux/linuxinterface.h"

#include "Core.h"
#include "SoundCore.h"
#include "Log.h"

#ifndef USE_COREAUDIO
#include <SDL.h>
#else
#include <AudioToolbox/AudioToolbox.h>
#endif // USE_COREAUDIO

#include <unordered_map>
#include <memory>
#include <iostream>
#include <iomanip>

namespace
{

  // these have to come from EmulatorOptions
  std::string audioDeviceName;
  size_t audioBuffer = 0;

#ifdef USE_COREAUDIO
OSStatus DirectSoundRenderProc(void * inRefCon,
                               AudioUnitRenderActionFlags * ioActionFlags,
                               const AudioTimeStamp * inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList * ioData);
#else
  size_t getBytesPerSecond(const SDL_AudioSpec & spec)
  {
    const size_t bitsPerSample = spec.format & SDL_AUDIO_MASK_BITSIZE;
    const size_t bytesPerFrame = spec.channels * bitsPerSample / 8;
    return spec.freq * bytesPerFrame;
  }

  size_t nextPowerOf2(size_t n)
  {
    size_t k = 1;
    while (k < n)
      k *= 2;
    return k;
  }
#endif // USE_COREAUDIO

  class DirectSoundGenerator : public IDirectSoundBuffer
  {
  public:
    DirectSoundGenerator(LPCDSBUFFERDESC lpcDSBufferDesc, const char * deviceName, const size_t ms);
    virtual ~DirectSoundGenerator() override;
    virtual HRESULT Release() override;

    virtual HRESULT Stop() override;
    virtual HRESULT Play( DWORD dwReserved1, DWORD dwReserved2, DWORD dwFlags ) override;

    void resetUnderruns();

    void printInfo();
    sa2::SoundInfo getInfo();

#ifdef USE_COREAUDIO
    friend OSStatus DirectSoundRenderProc(void * inRefCon,
                                          AudioUnitRenderActionFlags * ioActionFlags,
                                          const AudioTimeStamp * inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList * ioData);
    void setVolumeIfNecessary();
#endif // USE_COREAUDIO

  private:
#ifndef USE_COREAUDIO
    static void staticAudioCallback(void* userdata, uint8_t* stream, int len);

    void audioCallback(uint8_t* stream, int len);

    std::vector<uint8_t> myMixerBuffer;

    SDL_AudioDeviceID myAudioDevice;
    SDL_AudioSpec myAudioSpec;
#else
    std::vector<uint8_t> myMixerBuffer;

    AudioUnit outputUnit;
    Float32 volume;
#endif // USE_COREAUDIO

    size_t myBytesPerSecond;

#ifndef USE_COREAUDIO
    uint8_t * mixBufferTo(uint8_t * stream);
#endif
  };

  std::unordered_map<DirectSoundGenerator *, std::shared_ptr<DirectSoundGenerator> > activeSoundGenerators;

#ifndef USE_COREAUDIO
  void DirectSoundGenerator::staticAudioCallback(void* userdata, uint8_t* stream, int len)
  {
    DirectSoundGenerator * generator = static_cast<DirectSoundGenerator *>(userdata);
    return generator->audioCallback(stream, len);
  }

  void DirectSoundGenerator::audioCallback(uint8_t* stream, int len)
  {
    LPVOID lpvAudioPtr1, lpvAudioPtr2;
    DWORD dwAudioBytes1, dwAudioBytes2;
    const size_t bytesRead = Read(len, &lpvAudioPtr1, &dwAudioBytes1, &lpvAudioPtr2, &dwAudioBytes2);

    myMixerBuffer.resize(bytesRead);

    uint8_t * dest = myMixerBuffer.data();
    if (lpvAudioPtr1 && dwAudioBytes1)
    {
      memcpy(dest, lpvAudioPtr1, dwAudioBytes1);
      dest += dwAudioBytes1;
    }
    if (lpvAudioPtr2 && dwAudioBytes2)
    {
      memcpy(dest, lpvAudioPtr2, dwAudioBytes2);
      dest += dwAudioBytes2;
    }

    stream = mixBufferTo(stream);

    const size_t gap = len - bytesRead;
    if (gap)
    {
      memset(stream, myAudioSpec.silence, gap);
    }
  }
#endif // USE_COREAUDIO

  DirectSoundGenerator::DirectSoundGenerator(LPCDSBUFFERDESC lpcDSBufferDesc, const char * deviceName, const size_t ms)
    : IDirectSoundBuffer(lpcDSBufferDesc)
#ifndef USE_COREAUDIO
    , myAudioDevice(0)
#else
    , outputUnit(0)
    , volume(0)
#endif
    , myBytesPerSecond(0)
  {
#ifndef USE_COREAUDIO
    SDL_zero(myAudioSpec);

    SDL_AudioSpec want;
    SDL_zero(want);

    _ASSERT(ms > 0);

    want.freq = mySampleRate;
    want.format = AUDIO_S16LSB;
    want.channels = myChannels;
    want.samples = std::min<size_t>(MAX_SAMPLES, nextPowerOf2(mySampleRate * ms / 1000));
    want.callback = staticAudioCallback;
    want.userdata = this;
    myAudioDevice = SDL_OpenAudioDevice(deviceName, 0, &want, &myAudioSpec, 0);

    if (myAudioDevice)
    {
      myBytesPerSecond = getBytesPerSecond(myAudioSpec);
    }
    else
    {
      throw std::runtime_error(sa2::decorateSDLError("SDL_OpenAudioDevice"));
    }
#else
    AudioComponentDescription desc = { 0 };
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (comp == NULL)
    {
      fprintf(stderr, "can't find audio component\n");
      return;
    }
    
    if (AudioComponentInstanceNew(comp, &outputUnit) != noErr)
    {
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
                             sizeof(input)) != noErr)
    {
      fprintf(stderr, "can't set callback property\n");
      return;
    }
    
    setVolumeIfNecessary();
    
    if (AudioUnitInitialize(outputUnit) != noErr)
    {
      fprintf(stderr, "can't initialize output unit\n");
      return;
    }
    
    OSStatus status = AudioOutputUnitStart(outputUnit);
    fprintf(stderr, "output unit %p, status %d\n", outputUnit, status);
#endif
  }

  DirectSoundGenerator::~DirectSoundGenerator()
  {
#ifndef USE_COREAUDIO
    SDL_PauseAudioDevice(myAudioDevice, 1);
    SDL_CloseAudioDevice(myAudioDevice);
#endif // USE_COREAUDIO
  }

  HRESULT DirectSoundGenerator::Release()
  {
#ifndef USE_COREAUDIO
    activeSoundGenerators.erase(this);  // this will force the destructor
    return IUnknown::Release();
#else
    AudioOutputUnitStop(outputUnit);
    AudioUnitUninitialize(outputUnit);
    AudioComponentInstanceDispose(outputUnit);
    outputUnit = 0;
    return S_OK;
#endif // USE_COREAUDIO
  }

  HRESULT DirectSoundGenerator::Stop()
  {
    const HRESULT res = IDirectSoundBuffer::Stop();
#ifndef USE_COREAUDIO
    SDL_PauseAudioDevice(myAudioDevice, 1);
#endif // USE_COREAUDIO
    return res;
  }
  
  HRESULT DirectSoundGenerator::Play( DWORD dwReserved1, DWORD dwReserved2, DWORD dwFlags )
  {
    const HRESULT res = IDirectSoundBuffer::Play(dwReserved1, dwReserved2, dwFlags);
#ifndef USE_COREAUDIO
    SDL_PauseAudioDevice(myAudioDevice, 0);
#endif // USE_COREAUDIO
    return res;
  }

  void DirectSoundGenerator::printInfo()
  {
#ifndef USE_COREAUDIO
    const DWORD bytesInBuffer = GetBytesInBuffer();
    std::cerr << "Channels: " << (int)myAudioSpec.channels;
    std::cerr << ", buffer: " << std::setw(6) << bytesInBuffer;
    const double time = double(bytesInBuffer) / myBytesPerSecond * 1000;
    std::cerr << ", " << std::setw(8) << time << " ms";
    std::cerr << ", underruns: " << std::setw(10) << GetBufferUnderruns() << std::endl;
#endif // USE_COREAUDIO
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

    if (info.running && myBytesPerSecond > 0)
    {
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

#ifndef USE_COREAUDIO
  uint8_t * DirectSoundGenerator::mixBufferTo(uint8_t * stream)
  {
    // we could copy ADJUST_VOLUME from SDL_mixer.c and avoid all copying and (rare) race conditions
    const double logVolume = GetLogarithmicVolume();
    // same formula as QAudio::convertVolume()
    const double linVolume = logVolume > 0.99 ? 1.0 : -std::log(1.0 - logVolume) / std::log(100.0);
    const uint8_t svolume = uint8_t(linVolume * SDL_MIX_MAXVOLUME);

    const size_t len = myMixerBuffer.size();
    memset(stream, 0, len);
    SDL_MixAudioFormat(stream, myMixerBuffer.data(), myAudioSpec.format, len, svolume);
    return stream + len;
  }
#endif // USE_COREAUDIO
  
#ifdef USE_COREAUDIO
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
                                0) == noErr)
      {
        volume = linVolume;
      }
      else
      {
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
    dsg->Read(size,
              &lpvAudioPtr1,
              &dwAudioBytes1,
              &lpvAudioPtr2,
              &dwAudioBytes2);
    
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
#endif // USE_COREAUDIO
  
}

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

namespace sa2
{

  void printAudioInfo()
  {
    for (const auto & it : activeSoundGenerators)
    {
      const auto generator = it.second;
      generator->printInfo();
    }
  }

  void resetAudioUnderruns()
  {
    for (const auto & it : activeSoundGenerators)
    {
      const auto generator = it.second;
      generator->resetUnderruns();
    }
  }

  std::vector<SoundInfo> getAudioInfo()
  {
    std::vector<SoundInfo> info;
    info.reserve(activeSoundGenerators.size());

    for (const auto & it : activeSoundGenerators)
    {
      const auto & generator = it.second;
      info.push_back(generator->getInfo());
    }

    return info;
  }

  void setAudioOptions(const common2::EmulatorOptions & options)
  {
    audioDeviceName = options.audioDeviceName;
    audioBuffer = options.audioBuffer;
  }

}
