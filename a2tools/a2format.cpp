//
//  a2format.cpp
//  a2tools
//
//  Created by sh95014 on 8/22/23.
//

#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "DiskImg.h"

#define SAFE(x) ((x) != 0 ? (x) : "<null>")

using namespace DiskImgLib;

static bool verbose = false;

const char *getString(int argc, const char *argv[], int index) {
    if (index < argc) {
        return argv[index];
    }
    return 0;
}

long getLong(int argc, const char *argv[], int index) {
    if (index < argc) {
        return atol(argv[index]);
    }
    return INT_MIN;
}

void logErrorIf(int condition, const char *format, ...) {
    if (verbose && condition) {
        va_list args;
        va_start(args, format);
        vfprintf(stderr, format, args);
        va_end(args);
    }
}

void logError(const char *format, ...) {
    if (verbose) {
        va_list args;
        va_start(args, format);
        vfprintf(stderr, format, args);
        va_end(args);
    }
}

void diskImgDebugMsgHandler(const char* file, int line, const char* msg) {
#if DEBUG
    if (verbose) {
        fprintf(stderr, "%s:%d %s\n", file, line, msg);
    }
#endif
}

bool equalString(const char *s1, const char *s2) {
    return strcmp(s1, s2) == 0;
}

DiskImg::FSFormat getFileSystemFormat(const char *string) {
    if (string != 0) {
        if (equalString(string, "prodos")) {
            return DiskImg::kFormatProDOS;
        } else if (equalString(string, "dos")) {
            return DiskImg::kFormatDOS33;
        } else if (equalString(string, "pascal")) {
            return DiskImg::kFormatPascal;
        }
    }
    return DiskImg::kFormatUnknown;
}

int main(int argc, const char * argv[]) {
    const char *imageFileName = 0;
    DiskImg::FSFormat fileSystemFormat = DiskImg::kFormatUnknown;
    long blockCount = -1;
    
    for (int i = 1; i < argc; i++) {
        if (equalString(argv[i], "-i")) {
            imageFileName = getString(argc, argv, ++i);
            logErrorIf(imageFileName == 0, "Path name expected.\n");
        } else if (equalString(argv[i], "--fs-format")) {
            const char *string = getString(argc, argv, ++i);
            logErrorIf(string == 0, "Expected format 'dos', 'prodos', or 'pascal'\n");
            fileSystemFormat = getFileSystemFormat(string);
        } else if (equalString(argv[i], "-f")) {
            const long size = getLong(argc, argv, ++i);
            if (size == 140 || size == 800) {
                blockCount = size * 2;
            } else {
                logError("Expected size '140' or '800'\n", argv[i]);
            }
        } else if (equalString(argv[i], "--verbose")) {
            verbose = true;
        } else {
            logError("Unexpected argument '%s'\n", argv[i]);
            return -1;
        }
    }
    
    if (imageFileName == 0) {
        logError("Image file name is required.");
        return -1;
    }
    if (blockCount < 0) {
        logError("Size is unspecified or invalid, substituting with default.\n");
        blockCount = 140 * 2;
    }
    if (fileSystemFormat == DiskImg::kFormatUnknown) {
        logError("File system format is unspecified or invalid, substituting with default.\n");
        fileSystemFormat = DiskImg::kFormatDOS33;
    }

    Global::SetDebugMsgHandler(&diskImgDebugMsgHandler);
    Global::AppInit();
    DiskImg *diskImg = new DiskImg;
    DIError error;
    
    error = diskImg->CreateImage(imageFileName,
                                 0,
                                 DiskImg::kOuterFormatNone,
                                 DiskImg::kFileFormatUnadorned,
                                 DiskImg::kPhysicalFormatSectors,
                                 0,
                                 DiskImg::kSectorOrderProDOS,
                                 DiskImg::kFormatGenericProDOSOrd,
                                 blockCount,
                                 true);
    if (error != kDIErrNone) {
        return -1;
    }
    
    const char *volumeLabel = (fileSystemFormat == DiskImg::kFormatDOS33) ? "DOS" : "TEMP";
    error = diskImg->FormatImage(fileSystemFormat, volumeLabel);
    if (error != kDIErrNone) {
        return -1;
    }
    
    error = diskImg->CloseImage();
    if (error != kDIErrNone) {
        return -1;
    }
    delete diskImg;

    return 0;
}
