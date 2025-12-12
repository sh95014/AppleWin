# Mariani

Mariani is an emulator of the Apple ][ and //e computers for macOS. Click [here](https://sh95014.github.io/AppleWin/) for details if you just want to use it, the rest of this document is mainly for developers who wish to build their own version of the app.

## Introduction

Mariani is an unofficial native macOS UI for [AppleWin](https://github.com/AppleWin/AppleWin), by way of [Andrea](https://github.com/audetto)'s [Raspberry Pi port](https://github.com/audetto/AppleWin). Key goals of this project include a modern native macOS UI for the emulator, and broad compatibility with upstream code so we can easily pick up any future revisions.

## Features

Mariani supports most user-facing features of AppleWin, but additionally supports:

- Native, universal macOS UI
- Screen recording
- Copy screenshot to pasteboard
- Disk image browser, including [syntax-highlighted listings](https://sh95014.github.io/AppleWin/images/basic.png) for Applesoft and Integer BASIC, as well as hex viewer for other file types
- Separate windows for the [Debugger](/source/frontends/mariani/debugger/README.md) and a [memory viewer](https://sh95014.github.io/AppleWin/images/memory.png) (including a live viewer for the current BASIC program!)
- [AppleScript](/source/frontends/mariani/scripting/README.md) support for automation

Please [report any issues](https://github.com/sh95014/AppleWin/issues) you run into.

## Build Mariani

Note that the default git branch for Mariani is `macos`, not `master`. The latter is kept clean for upstream contributions.

### Dependencies

The only external library that Mariani requires are `boost` and `libslirp`, most easily satisfied using [Homebrew](https://brew.sh). After you install Homebrew, pick it up below:

```
brew install boost libslirp
```

### Checkout

Now grab the source code:

```
git clone https://github.com/sh95014/AppleWin.git --recursive
```

Load up the Xcode project, make sure you select the "Mariani" scheme, and then target for "My Mac".

## Build sa2

sa2 is a command-line tool, basically identical to Andrea's Linux port. It's useful to compare behaviors and bugs.

### Dependencies

sa2 needs more external libraries than Mariani, which you can grab for macOS using [Homebrew](https://brew.sh). After you install Homebrew, pick up the required packages below:

```
brew install boost cmake pkgconfig libyaml minizip libslirp libpcap sdl2 sdl2_image
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

Note that some of the settings (most of the ones stored in `~/.config/applewin/applewin.conf`) will affect both Mariani and sa2.

## Build a Universal (x86 and Apple Silicon) Mariani

"Mariani Universal" is the target used to build a universal (x86 and Apple Silicon) app, and will *not* build out of the box because Homebrew does not support universal libraries.

### If You Have Both Machines

On the x86 Mac, `brew install libslirp` and copy `libslirp.a`, `libintl.a`, and `libglib-2.0.a` from `/usr/local/lib` to your Apple Silicon Mac, perhaps in a folder named `x86_libs`.

On the Apple Silicon Mac, `brew install libslirp`, then combine the libraries:

```
lipo -create -arch arm64 /opt/homebrew/lib/libslirp.a -arch x86_64 ~/Develop/x86_libs/libslirp.a -output ~/Develop/universal/libslirp.a
lipo -create -arch arm64 /opt/homebrew/lib/libintl.a -arch x86_64 ~/Develop/x86_libs/libintl.a -output ~/Develop/universal/libintl.a
lipo -create -arch arm64 /opt/homebrew/lib/libglib-2.0.a -arch x86_64 ~/Develop/x86_libs/libglib-2.0.a -output ~/Develop/universal/libglib-2.0.a
```

You can verify success using the `file` command:

```
$ file *
libglib-2.0.a:              Mach-O universal binary with 2 architectures: [x86_64:current ar archive random library] [arm64]
libglib-2.0.a (for architecture x86_64):	current ar archive random library
libglib-2.0.a (for architecture arm64):	current ar archive random library
libintl.a:                  Mach-O universal binary with 2 architectures: [x86_64:current ar archive random library] [arm64:current ar archive random library]
libintl.a (for architecture x86_64):	current ar archive random library
libintl.a (for architecture arm64):	current ar archive random library
libslirp.a:                 Mach-O universal binary with 2 architectures: [x86_64:current ar archive random library] [arm64:current ar archive random library]
libslirp.a (for architecture x86_64):	current ar archive random library
libslirp.a (for architecture arm64):	current ar archive random library
```

The Xcode project expects them to be placed in `../universal/` relative to itself but you can change that to your liking.

### If You Only Have an Apple Silicon Mac

You'll have to follow [these instructions](https://gist.github.com/sh95014/36ca609c722d3998d57a44c1c5c90ab3) to install the x86 versions of the relevant libraries under Rosetta 2, which will likely stop working on macOS versions beyond 27.

Once you've installed both versions of the required libraries, combine them:
```
lipo -create -arch arm64 /opt/homebrew/lib/libslirp.a -arch x86_64 /usr/local/homebrew/lib/libslirp.a -output ~/Develop/universal/libslirp.a
lipo -create -arch arm64 /opt/homebrew/lib/libintl.a -arch x86_64 /usr/local/homebrew/lib/libintl.a -output ~/Develop/universal/libintl.a
lipo -create -arch arm64 /opt/homebrew/lib/libglib-2.0.a -arch x86_64 /usr/local/homebrew/lib/libglib-2.0.a -output ~/Develop/universal/libglib-2.0.a
```

## FAQs

### macOS says Mariani may be malicious software?!

Recent versions of macOS ship with a security feature called Gatekeeper, which requires apps to be "notarized" or the scary warning will appear. Given the not-completely-clear legal status of emulating even decades-old hardware, I'm not going to risk my developer account to get Mariani notarized.

You can bypass the warning just for Mariani in Settings > Security & Privacy, or build Mariani yourself in Xcode.

### Can I launch Mariani from the command line?

If you installed Mariani in one of the usual places, you can launch it from the command line:

```
open -a Mariani --args -1 "/Users/sh95014/Karateka.dsk"
```

The command-line parameters after `--args` are passed to the AppleWin engine, in this case inserting a diskette into drive 1. Note that the full path of the diskette must be specified.

### Do you support printers?

Experimental support for printers is available in an [unmaintained branch](https://github.com/sh95014/AppleWin/tree/printer-support). The full feature needs considerable [upstream support](https://github.com/AppleWin/AppleWin/issues/1026).
