#include "frontends/sdl/sdirectsound.h"

#include "windows.h"
#include "linux/linuxinterface.h"

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

#ifdef USE_COREAUDIO
OSStatus DirectSoundRenderProc(void * inRefCon,
                               AudioUnitRenderActionFlags * ioActionFlags,
                               const AudioTimeStamp * inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList * ioData);
#endif // USE_COREAUDIO

  class DirectSoundGenerator
  {
  public:
    DirectSoundGenerator(IDirectSoundBuffer * buffer);
    ~DirectSoundGenerator();

    void stop();
    void writeAudio();

    void printInfo() const;
    sa2::SoundInfo getInfo() const;

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
    IDirectSoundBuffer * myBuffer;

#ifndef USE_COREAUDIO
    std::vector<Uint8> myMixerBuffer;

    SDL_AudioDeviceID myAudioDevice;
    SDL_AudioSpec myAudioSpec;
#else
    std::vector<uint8_t> myMixerBuffer;

    AudioUnit outputUnit;
    Float32 volume;
#endif // USE_COREAUDIO

    int myBytesPerSecond;

    void close();
    bool isRunning() const;
    bool isRunning();

    void mixBuffer(const void * ptr, const size_t size);
  };


  std::unordered_map<IDirectSoundBuffer *, std::shared_ptr<DirectSoundGenerator>> activeSoundGenerators;

  DirectSoundGenerator::DirectSoundGenerator(IDirectSoundBuffer * buffer)
    : myBuffer(buffer)
#ifndef USE_COREAUDIO
    , myAudioDevice(0)
#else
    , outputUnit(0)
    , volume(0)
#endif
    , myBytesPerSecond(0)
  {
#ifndef USE_COREAUDIO
    SDL_memset(&myAudioSpec, 0, sizeof(myAudioSpec));
#endif
  }

  DirectSoundGenerator::~DirectSoundGenerator()
  {
    close();
  }

  void DirectSoundGenerator::close()
  {
#ifndef USE_COREAUDIO
    SDL_CloseAudioDevice(myAudioDevice);
    myAudioDevice = 0;
#else
    AudioOutputUnitStop(outputUnit);
    AudioUnitUninitialize(outputUnit);
    AudioComponentInstanceDispose(outputUnit);
    outputUnit = 0;
#endif // USE_COREAUDIO
  }

  bool DirectSoundGenerator::isRunning() const
  {
#ifndef USE_COREAUDIO
    return myAudioDevice;
#else
    return outputUnit;
#endif
  }

  bool DirectSoundGenerator::isRunning()
  {
#ifndef USE_COREAUDIO
    if (myAudioDevice)
    {
      return true;
    }
#else
    if (outputUnit)
    {
      return true;
    }
#endif // USE_COREAUDIO

    DWORD dwStatus;
    myBuffer->GetStatus(&dwStatus);
    if (!(dwStatus & DSBSTATUS_PLAYING))
    {
      return false;
    }

#ifndef USE_COREAUDIO
    SDL_AudioSpec want;
    SDL_memset(&want, 0, sizeof(want));

    want.freq = myBuffer->sampleRate;
    want.format = AUDIO_S16LSB;
    want.channels = myBuffer->channels;
    want.samples = 4096;  // what does this really mean?
    want.callback = nullptr;
    myAudioDevice = SDL_OpenAudioDevice(nullptr, 0, &want, &myAudioSpec, 0);

    if (myAudioDevice)
    {
      const int bitsPerSample = myAudioSpec.format & SDL_AUDIO_MASK_BITSIZE;
      myBytesPerSecond = myAudioSpec.freq * myAudioSpec.channels * bitsPerSample / 8;

      SDL_PauseAudioDevice(myAudioDevice, 0);
      return true;
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
      return false;
    }
    
    if (AudioComponentInstanceNew(comp, &outputUnit) != noErr)
    {
      fprintf(stderr, "can't create output unit\n");
      return false;
    }
    
    AudioStreamBasicDescription absd = { 0 };
    absd.mSampleRate = myBuffer->sampleRate;
    absd.mFormatID = kAudioFormatLinearPCM;
    absd.mFormatFlags = kAudioFormatFlagIsSignedInteger;
    absd.mFramesPerPacket = 1;
    absd.mChannelsPerFrame = (UInt32)myBuffer->channels;
    absd.mBitsPerChannel = sizeof(SInt16) * CHAR_BIT;
    absd.mBytesPerPacket = sizeof(SInt16) * (UInt32)myBuffer->channels;
    absd.mBytesPerFrame = sizeof(SInt16) * (UInt32)myBuffer->channels;
    if (AudioUnitSetProperty(outputUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &absd,
                             sizeof(absd))) {
      fprintf(stderr, "can't set stream format\n");
      return false;
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
      return false;
    }
    
    setVolumeIfNecessary();
    
    if (AudioUnitInitialize(outputUnit) != noErr)
    {
      fprintf(stderr, "can't initialize output unit\n");
      return false;
    }
    
    OSStatus status = AudioOutputUnitStart(outputUnit);
    fprintf(stderr, "output unit %p, status %d\n", outputUnit, status);
#endif // USE_COREAUDIO

    return false;
  }

  void DirectSoundGenerator::printInfo() const
  {
    if (isRunning())
    {
#ifndef USE_COREAUDIO
      const int width = 5;
      const DWORD bytesInBuffer = myBuffer->GetBytesInBuffer();
      const Uint32 bytesInQueue = SDL_GetQueuedAudioSize(myAudioDevice);
      std::cerr << "Channels: " << (int)myAudioSpec.channels;
      std::cerr << ", buffer: " << std::setw(width) << bytesInBuffer;
      std::cerr << ", SDL: " << std::setw(width) << bytesInQueue;
      const double queue = double(bytesInBuffer + bytesInQueue) / myBytesPerSecond;
      std::cerr << ", queue: " << queue << " s" << std::endl;
#endif // USE_COREAUDIO
    }
  }

  sa2::SoundInfo DirectSoundGenerator::getInfo() const
  {
    // FIXME: The #ifdef'ed out bits probably need to be restored to use CoreAudio in sa2.
    
    sa2::SoundInfo info;
    info.running = isRunning();
#ifndef USE_COREAUDIO
    info.channels = myAudioSpec.channels;
#endif
    info.volume = myBuffer->GetLogarithmicVolume();

    if (info.running && myBytesPerSecond > 0.0)
    {
      const DWORD bytesInBuffer = myBuffer->GetBytesInBuffer();
#ifndef USE_COREAUDIO
      const Uint32 bytesInQueue = SDL_GetQueuedAudioSize(myAudioDevice);
#endif
      const float coeff = 1.0 / myBytesPerSecond;
      info.buffer = bytesInBuffer * coeff;
#ifndef USE_COREAUDIO
      info.queue = bytesInQueue * coeff;
#endif
      info.size = myBuffer->bufferSize * coeff;
    }

    return info;
  }

  void DirectSoundGenerator::stop()
  {
#ifndef USE_COREAUDIO
    if (myAudioDevice)
#else
    if (outputUnit)
#endif // USE_COREAUDIO
    {
#ifndef USE_COREAUDIO
      SDL_PauseAudioDevice(myAudioDevice, 1);
#endif
      close();
    }
  }

  void DirectSoundGenerator::mixBuffer(const void * ptr, const size_t size)
  {
#ifndef USE_COREAUDIO
    const double logVolume = myBuffer->GetLogarithmicVolume();
    // same formula as QAudio::convertVolume()
    const double linVolume = logVolume > 0.99 ? 1.0 : -std::log(1.0 - logVolume) / std::log(100.0);

    const Uint8 svolume = Uint8(linVolume * SDL_MIX_MAXVOLUME);

    // this is a bit of a waste copy-time, but it reuses SDL to do it properly
    myMixerBuffer.resize(size);
    memset(myMixerBuffer.data(), 0, size);
    SDL_MixAudioFormat(myMixerBuffer.data(), (const Uint8*)ptr, myAudioSpec.format, size, svolume);
    SDL_QueueAudio(myAudioDevice, myMixerBuffer.data(), size);
#endif // USE_COREAUDIO
  }

  void DirectSoundGenerator::writeAudio()
  {
    // this is autostart as we only do for the palying buffers
    // and AW might activate one later
    if (!isRunning())
    {
      return;
    }

#ifndef USE_COREAUDIO
    // CoreAudio audio units pull data via the DirectSoundRenderProc callback,
    // so writeAudio() doesn't actually do anything except tickle isRunning()
    // to initialize the outputUnit. This is all pretty pointless except I'd
    // like to keep the general structure of DirectSoundGenerator compatible
    // with Linux for now. It might be possible to get sa2 to switch to
    // CoreAudio on Macs for lower latency.
    
    // SDL does not have a maximum buffer size
    // we have to be careful not writing too much
    // otherwise AW starts generating a lot of samples
    // and we loose sync

    // assume SDL's buffer is the same size as AW's
    const int bytesFree = myBuffer->bufferSize - SDL_GetQueuedAudioSize(myAudioDevice);

    if (bytesFree > 0)
    {
      LPVOID lpvAudioPtr1, lpvAudioPtr2;
      DWORD dwAudioBytes1, dwAudioBytes2;
      myBuffer->Read(bytesFree, &lpvAudioPtr1, &dwAudioBytes1, &lpvAudioPtr2, &dwAudioBytes2);

      if (lpvAudioPtr1 && dwAudioBytes1)
      {
        mixBuffer(lpvAudioPtr1, dwAudioBytes1);
      }
      if (lpvAudioPtr2 && dwAudioBytes2)
      {
        mixBuffer(lpvAudioPtr2, dwAudioBytes2);
      }
    }
#endif // USE_COREAUDIO
  }

#ifdef USE_COREAUDIO

  void DirectSoundGenerator::setVolumeIfNecessary()
  {
    const double logVolume = myBuffer->GetLogarithmicVolume();
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
    
    DWORD size = (DWORD)(inNumberFrames * dsg->myBuffer->channels * sizeof(SInt16));
    
    LPVOID lpvAudioPtr1, lpvAudioPtr2;
    DWORD dwAudioBytes1, dwAudioBytes2;
    dsg->myBuffer->Read(size,
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
    // fill the rest with 0
    memset(data + dwAudioBytes1 + dwAudioBytes2, 0, size - (dwAudioBytes1 + dwAudioBytes2));
    
    dsg->setVolumeIfNecessary();
    
    return noErr;
  }
#endif // USE_COREAUDIO

}

void registerSoundBuffer(IDirectSoundBuffer * buffer)
{
  const std::shared_ptr<DirectSoundGenerator> generator = std::make_shared<DirectSoundGenerator>(buffer);
  activeSoundGenerators[buffer] = generator;
}

void unregisterSoundBuffer(IDirectSoundBuffer * buffer)
{
  const auto it = activeSoundGenerators.find(buffer);
  if (it != activeSoundGenerators.end())
  {
    // stop the QAudioOutput before removing. is this necessary?
    it->second->stop();
    activeSoundGenerators.erase(it);
  }
}

namespace sa2
{

  void stopAudio()
  {
    for (auto & it : activeSoundGenerators)
    {
      const std::shared_ptr<DirectSoundGenerator> & generator = it.second;
      generator->stop();
    }
  }

  void writeAudio()
  {
    for (auto & it : activeSoundGenerators)
    {
      const std::shared_ptr<DirectSoundGenerator> & generator = it.second;
      generator->writeAudio();
    }
  }

  void printAudioInfo()
  {
    for (auto & it : activeSoundGenerators)
    {
      const std::shared_ptr<DirectSoundGenerator> & generator = it.second;
      generator->printInfo();
    }
  }

  std::vector<SoundInfo> getAudioInfo()
  {
    std::vector<SoundInfo> info;
    info.reserve(activeSoundGenerators.size());

    for (auto & it : activeSoundGenerators)
    {
      const std::shared_ptr<DirectSoundGenerator> & generator = it.second;
      info.push_back(generator->getInfo());
    }

    return info;
  }

}
