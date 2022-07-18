# macOS

## Introduction

Mariani is a native macOS UI for [AppleWin](https://github.com/AppleWin/AppleWin), by way of [Andrea](https://github.com/audetto)'s [Raspberry Pi port](https://github.com/audetto/AppleWin).

But if what you want is a macOS command-line app, you can build it with the instructions below.

### Features

- Native, universal macOS UI
- Screen recording
- Copy screenshot to pasteboard
- Disk image browser, including syntax-highlighted listings for Applesoft and Integer BASIC, as well as hex viewer for other file types
- Floppy and hard disk image creation
- Full-screen support

### Known Issues

I consider Mariani to be at v1.0 in terms of functionality and stability. Here are the known issues:

https://github.com/sh95014/AppleWin/issues

Specifically, the following AppleWin features are not yet supported:

- [Debugger and Memory viewer](https://github.com/sh95014/AppleWin/issues/12)
- [Load/Save State](https://github.com/sh95014/AppleWin/issues/13)
- [Cassette support](https://github.com/sh95014/AppleWin/issues/16)
- [Numeric keypad joystick emulation](https://github.com/sh95014/AppleWin/issues/10)

### Roadmap

I plan to spend some time building (graphical) printer support, but I don't expect to spend a lot of time with the remaining known issues. I think the most generally useful ones in the list are the joystick emulation and maybe cassette support.

## Build Mariani

### Dependencies

The easiest way to build Mariani is to satisfy the dependencies using [Homebrew](https://brew.sh). After you install Homebrew, pick up the required packages below:

```
brew install Boost sdl2 libslirp
```

### Checkout

Now grab the source code:

```
git clone https://github.com/sh95014/AppleWin.git --recursive
```

Load up the Xcode project, and build the "Mariani" target for "My Mac".

"Mariani Universal" is the target used to build a universal (x86 and ARM) app, and will *not* build out of the box. Homebrew does not support universal (x86 and ARM) libraries, so you'll have to grab the [Development Library for SDL](https://www.libsdl.org/download-2.0.php) and also download/build [Boost](https://www.boost.org/users/download/) yourself. Here's a script that should help stitch the Boost binaries from both x86 and ARM builds together into an universal static library:

```
#!/bin/sh

rm -rf arm64 x86_64 universal stage bin.v2
rm -f b2 project-config*
./bootstrap.sh cxxflags="-arch x86_64 -arch arm64" cflags="-arch x86_64 -arch arm64" linkflags="-arch x86_64 -arch arm64"
./b2 toolset=clang-darwin target-os=darwin architecture=arm abi=aapcs cxxflags="-arch arm64" cflags="-arch arm64" linkflags="-arch arm64" -a
mkdir -p arm64 && cp stage/lib/*.dylib arm64 && cp stage/lib/*.a arm64
./b2 toolset=clang-darwin target-os=darwin architecture=x86 cxxflags="-arch x86_64" cflags="-arch x86_64" linkflags="-arch x86_64" abi=sysv binary-format=mach-o -a
mkdir x86_64 && cp stage/lib/*.dylib x86_64 && cp stage/lib/*.a x86_64
mkdir universal
for dylib in arm64/*; do 
  lipo -create -arch arm64 $dylib -arch x86_64 x86_64/$(basename $dylib) -output universal/$(basename $dylib); 
done
for dylib in universal/*; do
  lipo $dylib -info;
done
```

To get Uthernet support in "Mariani Universal", you'll also need to build [libslirp](https://gitlab.freedesktop.org/slirp/libslirp) on your own. I haven't done the work to add `U2_USE_SLIRP=1` to its pre-processor defines and link the library yet.

## Build sa2

sa2 is the binary produced by Andrea's port. It's not the focus of this repository but it's a more "faithful" AppleWin and very useful to compare behaviors and bugs.

### Dependencies

sa2 needs more external libraries than Mariani, which you can grab for macOS using [Homebrew](https://brew.sh). After you install Homebrew, pick up the required packages below:

```
brew install cmake pkgconfig libyaml minizip libslirp libpcap Boost sdl2 sdl2_image
```

### Checkout

Next, you'll probably want to generate an Xcode project to take advantage of source code indexing and finding the lines of code with warnings or errors. The parameters assume you just want the imgui frontend:

```
git clone https://github.com/sh95014/AppleWin.git --recursive
cd AppleWin
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=RELEASE -DBUILD_SA2=ON -G Xcode ..
open applewin.xcodeproj
```

The project should now launch in Xcode. Select the `ALL_BUILD` target and build. You can look under `Products` in the left pane to see where it is, because unfortunately Xcode does not seem to be able to run and debug the binary directly.

Or, you can follow basically the same instructions as in [Linux](linux.md), but in this case also simplified to build only the sa2 frontend:

```
git clone https://github.com/sh95014/AppleWin.git --recursive
cd AppleWin
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=RELEASE -DBUILD_SA2=ON ..
make
```

Note that some of the settings (most of the ones stored in `~/.applewin/applewin.conf`) will affect both Mariani and sa2.