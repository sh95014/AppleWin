//
//  a2tools.cpp
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

typedef enum {
    A2FORMAT            = 1 << 0,
    A2DIR               = 1 << 1,
} A2ROLE;

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
    if (condition) {
        va_list args;
        va_start(args, format);
        vfprintf(stderr, format, args);
        va_end(args);
    }
}

void logError(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
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

static int format(DiskImg *diskImg,
                  const char *imageFileName,
                  long blockCount,
                  DiskImg::FSFormat fileSystemFormat) {
    if (blockCount < 0) {
        logError("Size is unspecified or invalid, substituting with default.\n");
        blockCount = 140 * 2;
    }
    if (fileSystemFormat == DiskImg::kFormatUnknown) {
        logError("File system format is unspecified or invalid, substituting with default.\n");
        fileSystemFormat = DiskImg::kFormatDOS33;
    }
    
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
    
    return 0;
}

static const char *fileTypeStrings[] = {
    "NON", "BAD", "PCD", "PTX", "TXT", "PDA", "BIN", "FNT",
    "FOT", "BA3", "DA3", "WPF", "SOS", "$0D", "$0E", "DIR",
    "RPD", "RPI", "AFD", "AFM", "AFR", "SCL", "PFS", "$17",
    "$18", "ADB", "AWP", "ASP", "$1C", "$1D", "$1E", "$1F",
    "TDM", "$21", "$22", "$23", "$24", "$25", "$26", "$27",
    "$28", "$29", "8SC", "8OB", "8IC", "8LD", "P8C", "$2F",
    "$30", "$31", "$32", "$33", "$34", "$35", "$36", "$37",
    "$38", "$39", "$3A", "$3B", "$3C", "$3D", "$3E", "$3F",
    "DIC", "OCR", "FTD", "$43", "$44", "$45", "$46", "$47",
    "$48", "$49", "$4A", "$4B", "$4C", "$4D", "$4E", "$4F",
    "GWP", "GSS", "GDB", "DRW", "GDP", "HMD", "EDU", "STN",
    "HLP", "COM", "CFG", "ANM", "MUM", "ENT", "DVU", "FIN",
    "$60", "$61", "$62", "$63", "$64", "$65", "$66", "$67",
    "$68", "$69", "$6A", "BIO", "$6C", "TDR", "PRE", "HDV",
    "$70", "$71", "$72", "$73", "$74", "$75", "$76", "$77",
    "$78", "$79", "$7A", "$7B", "$7C", "$7D", "$7E", "$7F",
    "$80", "$81", "$82", "$83", "$84", "$85", "$86", "$87",
    "$88", "$89", "$8A", "$8B", "$8C", "$8D", "$8E", "$8F",
    "$90", "$91", "$92", "$93", "$94", "$95", "$96", "$97",
    "$98", "$99", "$9A", "$9B", "$9C", "$9D", "$9E", "$9F",
    "WP ", "$A1", "$A2", "$A3", "$A4", "$A5", "$A6", "$A7",
    "$A8", "$A9", "$AA", "GSB", "TDF", "BDF", "$AE", "$AF",
    "SRC", "OBJ", "LIB", "S16", "RTL", "EXE", "PIF", "TIF",
    "NDA", "CDA", "TOL", "DVR", "LDF", "FST", "$BE", "DOC",
    "PNT", "PIC", "ANI", "PAL", "$C4", "OOG", "SCR", "CDV",
    "FON", "FND", "ICN", "$CB", "$CC", "$CD", "$CE", "$CF",
    "$D0", "$D1", "$D2", "$D3", "$D4", "MUS", "INS", "MDI",
    "SND", "$D9", "$DA", "DBM", "$DC", "DDD", "$DE", "$DF",
    "LBR", "$E1", "ATK", "$E3", "$E4", "$E5", "$E6", "$E7",
    "$E8", "$E9", "$EA", "$EB", "$EC", "$ED", "R16", "PAS",
    "CMD", "$F1", "$F2", "$F3", "$F4", "$F5", "$F6", "$F7",
    "$F8", "OS ", "INT", "IVR", "BAS", "VAR", "REL", "SYS",
};

static int dir(DiskImg *diskImg,
               const char *imageFileName) {
    DIError error;
    
    error = diskImg->OpenImage(imageFileName, '/', true);
    if (error != kDIErrNone) {
        return -1;
    }
    
    error = diskImg->AnalyzeImage();
    if (error != kDIErrNone) {
        return -1;
    }
    
    DiskFS *diskFS = diskImg->OpenAppropriateDiskFS();
    if (diskFS == 0) {
        return -1;
    }
    
    diskFS->SetScanForSubVolumes(DiskFS::kScanSubEnabled);
    error = diskFS->Initialize(diskImg, DiskFS::kInitFull);
    if (error != kDIErrNone) {
        delete diskFS;
        return -1;
    }
    
    // find the volume directory, if any
    A2File *volumeDirectory = 0;
    A2File *file;
    file = diskFS->GetNextFile(0);
    while (file != 0) {
        if (file->IsVolumeDirectory()) {
            volumeDirectory = file;
            break;
        }
        file = diskFS->GetNextFile(file);
    }
    
    if (volumeDirectory == 0) {
        // DOS doesn't have one, proceed anyway.
        file = diskFS->GetNextFile(0);
        while (file != 0) {
            di_off_t size;
            if (file->IsDirectory()) {
                size = file->GetDataLength();
            } else if (file->GetRsrcLength() >= 0) {
                size = file->GetDataLength() + file->GetRsrcLength();
            } else {
                size = file->GetDataLength();
            }
            printf("%s:%04X %12lld %s\n", fileTypeStrings[file->GetFileType()], file->GetAuxType(), (long long)size, file->GetFileName());
            file = diskFS->GetNextFile(file);
        }
    }
    
    delete diskFS;
    return 0;
}

int main(int argc, const char * argv[]) {
    const char *imageFileName = 0;
    DiskImg::FSFormat fileSystemFormat = DiskImg::kFormatUnknown;
    long blockCount = -1;
    A2ROLE role;
    
    // strip any path components from argv[0]
    const char *name = strrchr(argv[0], '/');
    name = (name != NULL) ? name + 1 : argv[0];
    
    if (equalString(name, "a2format")) {
        role = A2FORMAT;
    } else if (equalString(name, "a2dir")) {
        role = A2DIR;
    } else {
        logError("Unknown command '%s'\n", name);
        return -1;
    }
    
    for (int i = 1; i < argc; i++) {
        if (equalString(argv[i], "-i")) {
            imageFileName = getString(argc, argv, ++i);
            logErrorIf(imageFileName == 0, "Path name expected.\n");
        } else if ((role & A2FORMAT) && equalString(argv[i], "--fs-format")) {
            const char *string = getString(argc, argv, ++i);
            logErrorIf(string == 0, "Expected format 'dos', 'prodos', or 'pascal'\n");
            fileSystemFormat = getFileSystemFormat(string);
        } else if ((role & A2FORMAT) && equalString(argv[i], "-f")) {
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
        logError("Image file name is required.\n");
        return -1;
    }
    
    Global::SetDebugMsgHandler(&diskImgDebugMsgHandler);
    Global::AppInit();
    DiskImg *diskImg = new DiskImg;
    
    int status = 0;
    switch (role) {
        case A2FORMAT:
            status = format(diskImg, imageFileName, blockCount, fileSystemFormat);
            break;
        case A2DIR:
            status = dir(diskImg, imageFileName);
            break;
    }
    
    DIError error = diskImg->CloseImage();
    if (error != kDIErrNone) {
        return -1;
    }
    delete diskImg;

    return status;
}
