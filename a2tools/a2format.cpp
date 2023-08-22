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

#define SAFE(x) ((x) != NULL ? (x) : "<null>")

using namespace DiskImgLib;

const char *getString(int argc, const char *argv[], int index) {
    if (index < argc) {
        return argv[index];
    }
    return NULL;
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
    fprintf(stderr, "%s:%d %s\n", file, line, msg);
#endif
}

bool equalString(const char *s1, const char *s2) {
    return strcmp(s1, s2) == 0;
}

bool hasSuffix(const char *string, const char *suffix) {
    const size_t stringLength = strlen(string);
    const size_t suffixLength = strlen(suffix);
    if (suffixLength > stringLength) {
        return false;
    }
    return equalString(string + stringLength - suffixLength, suffix);
}

DiskImg::OuterFormat getOuterFormat(const char *string) {
    if (string != NULL) {
        if (equalString(string, "z")) {
            return DiskImg::kOuterFormatCompress;
        }
        else if (equalString(string, "gz")) {
            return DiskImg::kOuterFormatGzip;
        }
        else if (equalString(string, "bz2")) {
            return DiskImg::kOuterFormatBzip2;
        }
        else if (equalString(string, "zip")) {
            return DiskImg::kOuterFormatZip;
        }
    }
    return DiskImg::kOuterFormatNone;
}

DiskImg::FileFormat getFileFormat(const char *string) {
    if (equalString(string, "unadorned")) {
        return DiskImg::kFileFormatUnadorned;
    }
    else if (equalString(string, "2mg")) {
        return DiskImg::kFileFormat2MG;
    }
    else if (equalString(string, "copy42")) {
        return DiskImg::kFileFormatDiskCopy42;
    }
    else if (equalString(string, "copy60")) {
        return DiskImg::kFileFormatDiskCopy60;
    }
    else if (equalString(string, "davex")) {
        return DiskImg::kFileFormatDavex;
    }
    else if (equalString(string, "hdv")) {
        return DiskImg::kFileFormatSim2eHDV;
    }
    else if (equalString(string, "trackstar")) {
        return DiskImg::kFileFormatTrackStar;
    }
    else if (equalString(string, "fdi")) {
        return DiskImg::kFileFormatFDI;
    }
    else if (equalString(string, "nufx")) {
        return DiskImg::kFileFormatNuFX;
    }
    else if (equalString(string, "ddd")) {
        return DiskImg::kFileFormatDDD;
    }
    else if (equalString(string, "ddddeluxe")) {
        return DiskImg::kFileFormatDDDDeluxe;
    }
    return DiskImg::kFileFormatUnknown;
}

DiskImg::FileFormat getImpliedFileFormat(const char *string) {
    if (hasSuffix(string, ".po") || hasSuffix(string, ".do") || hasSuffix(string, ".nib") ||
        hasSuffix(string, ".raw") || hasSuffix(string, ".d13")) {
        return DiskImg::kFileFormatUnadorned;
    }
    else if (hasSuffix(string, ".2mg") || hasSuffix(string, ".2img")) {
        return DiskImg::kFileFormat2MG;
    }
    else if (hasSuffix(string, ".dsk") || hasSuffix(string, ".disk")) {
        return DiskImg::kFileFormatDiskCopy42;
    }
    else if (hasSuffix(string, ".dc6")) {
        return DiskImg::kFileFormatDiskCopy60;
    }
    else if (hasSuffix(string, ".hdv")) {
        return DiskImg::kFileFormatSim2eHDV;
    }
    else if (hasSuffix(string, ".app")) {
        return DiskImg::kFileFormatTrackStar;
    }
    else if (hasSuffix(string, ".fdi")) {
        return DiskImg::kFileFormatFDI;
    }
    else if (hasSuffix(string, ".shk") || hasSuffix(string, ".sdk") || hasSuffix(string, ".bxy")) {
        return DiskImg::kFileFormatNuFX;
    }
    return DiskImg::kFileFormatUnknown;
}

DiskImg::PhysicalFormat getPhysicalFormat(const char *string) {
    if (string != NULL) {
        if (equalString(string, "sectors")) {
            return DiskImg::kPhysicalFormatSectors;
        }
        else if (equalString(string, "6656")) {
            return DiskImg::kPhysicalFormatNib525_6656;
        }
        else if (equalString(string, "6384")) {
            return DiskImg::kPhysicalFormatNib525_6384;
        }
        else if (equalString(string, "var")) {
            return DiskImg::kPhysicalFormatNib525_Var;
        }
    }
    return DiskImg::kPhysicalFormatUnknown;
}

const DiskImg::NibbleDescr* getNibbleDescr(const char *string) {
    if (string != NULL) {
        if (equalString(string, "dos33")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrDOS33Std);
        }
        else if (equalString(string, "dos33patched")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrDOS33Patched);
        }
        else if (equalString(string, "dos33ignorechecksum")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrDOS33IgnoreChecksum);
        }
        else if (equalString(string, "dos32")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrDOS32Std);
        }
        else if (equalString(string, "dos32patched")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrDOS32Patched);
        }
        else if (equalString(string, "muse32")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrMuse32);
        }
        else if (equalString(string, "rdos33")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrRDOS33);
        }
        else if (equalString(string, "rdos32")) {
            return DiskImg::GetStdNibbleDescr(DiskImg::kNibbleDescrRDOS32);
        }
    }
    return NULL;
}

DiskImg::SectorOrder getSectorOrder(const char *string) {
    if (string != NULL) {
        if (equalString(string, "prodos")) {
            return DiskImg::kSectorOrderProDOS;
        }
        else if (equalString(string, "dos")) {
            return DiskImg::kSectorOrderDOS;
        }
        else if (equalString(string, "cpm")) {
            return DiskImg::kSectorOrderCPM;
        }
        else if (equalString(string, "physical")) {
            return DiskImg::kSectorOrderPhysical;
        }
    }
    return DiskImg::kSectorOrderUnknown;
}

DiskImg::FSFormat getFileSystemFormat(const char *string) {
    if (string != NULL) {
        if (equalString(string, "prodos")) {
            return DiskImg::kFormatProDOS;
        }
        else if (equalString(string, "dos33")) {
            return DiskImg::kFormatDOS33;
        }
        else if (equalString(string, "dos32")) {
            return DiskImg::kFormatDOS32;
        }
        else if (equalString(string, "pascal")) {
            return DiskImg::kFormatPascal;
        }
        else if (equalString(string, "machfs")) {
            return DiskImg::kFormatMacHFS;
        }
        else if (equalString(string, "macmfs")) {
            return DiskImg::kFormatMacMFS;
        }
        else if (equalString(string, "lisa")) {
            return DiskImg::kFormatLisa;
        }
        else if (equalString(string, "cpm")) {
            return DiskImg::kFormatCPM;
        }
        else if (equalString(string, "msdos")) {
            return DiskImg::kFormatMSDOS;
        }
        else if (equalString(string, "iso9660")) {
            return DiskImg::kFormatISO9660;
        }
        else if (equalString(string, "rdos33")) {
            return DiskImg::kFormatRDOS33;
        }
        else if (equalString(string, "rdos32")) {
            return DiskImg::kFormatRDOS32;
        }
        else if (equalString(string, "rdos3")) {
            return DiskImg::kFormatRDOS3;
        }
        else if (equalString(string, "unidos")) {
            return DiskImg::kFormatUNIDOS;
        }
        else if (equalString(string, "ozdos")) {
            return DiskImg::kFormatOzDOS;
        }
        else if (equalString(string, "cffa4")) {
            return DiskImg::kFormatCFFA4;
        }
        else if (equalString(string, "cffa8")) {
            return DiskImg::kFormatCFFA8;
        }
        else if (equalString(string, "macpart")) {
            return DiskImg::kFormatMacPart;
        }
        else if (equalString(string, "microdrive")) {
            return DiskImg::kFormatMicroDrive;
        }
        else if (equalString(string, "focusdrive")) {
            return DiskImg::kFormatFocusDrive;
        }
        else if (equalString(string, "gutenberg")) {
            return DiskImg::kFormatGutenberg;
        }
    }
    return DiskImg::kFormatUnknown;
}

int main(int argc, const char * argv[]) {
    const char *pathName = NULL;
    const char *storageName = NULL;
    DiskImg::OuterFormat outerFormat = DiskImg::kOuterFormatNone;
    DiskImg::FileFormat fileFormat = DiskImg::kFileFormatUnknown;
    DiskImg::PhysicalFormat physicalFormat = DiskImg::kPhysicalFormatUnknown;
    const DiskImg::NibbleDescr *nibbleDescr = NULL;
    DiskImg::SectorOrder sectorOrder = DiskImg::kSectorOrderUnknown;
    DiskImg::FSFormat fileSystemFormat = DiskImg::kFormatUnknown;
    long tracks = -1;
    long sectors = -1;
    const char *volumeLabel = NULL;
    
    for (int i = 1; i < argc; i++) {
        if (equalString(argv[i], "-i")) {
            pathName = getString(argc, argv, ++i);
            logErrorIf(pathName == NULL, "Path name expected after -i.\n");
            if (fileFormat == DiskImg::kFileFormatUnknown) {
                fileFormat = getImpliedFileFormat(pathName);
            }
        }
        else if (equalString(argv[i], "--storage-name")) {
            storageName = getString(argc, argv, ++i);
            logErrorIf(storageName == NULL, "Storage name expected after --storage-name.\n");
        }
        else if (equalString(argv[i], "--outer-format")) {
            const char *outerFormatString = getString(argc, argv, ++i);
            logErrorIf(outerFormatString == NULL, "Outer format name expected after --outer-format.\n");
            outerFormat = getOuterFormat(outerFormatString);
        }
        else if (equalString(argv[i], "--file-format")) {
            const char *fileFormatString = getString(argc, argv, ++i);
            logErrorIf(fileFormatString == NULL, "File format expected after --file-format.\n");
            fileFormat = getFileFormat(fileFormatString);
        }
        else if (equalString(argv[i], "--physical-format")) {
            const char *physicalFormatString = getString(argc, argv, ++i);
            logErrorIf(physicalFormatString == NULL, "Physical format expected after --physical-format.\n");
            physicalFormat = getPhysicalFormat(physicalFormatString);
        }
        else if (equalString(argv[i], "--nibble-descr")) {
            const char *string = getString(argc, argv, ++i);
            logErrorIf(string == NULL, "Nibble descriptor expected after --nibble-descr.\n");
            nibbleDescr = getNibbleDescr(string);
        }
        else if (equalString(argv[i], "--sector-order")) {
            const char *string = getString(argc, argv, ++i);
            logErrorIf(string == NULL, "Sector order expected after --sector-order.\n");
            sectorOrder = getSectorOrder(string);
        }
        else if (equalString(argv[i], "--fs-format")) {
            const char *string = getString(argc, argv, ++i);
            logErrorIf(string == NULL, "File system format expected after --sector-order.\n");
            fileSystemFormat = getFileSystemFormat(string);
        }
        else if (equalString(argv[i], "-t")) {
            tracks = getLong(argc, argv, ++i);
        }
        else if (equalString(argv[i], "-s")) {
            sectors = getLong(argc, argv, ++i);
        }
        else if (equalString(argv[i], "-v")) {
            volumeLabel = getString(argc, argv, ++i);
            logErrorIf(volumeLabel == NULL, "Volume label expected after -v.\n");
        }
    }
    
    if (pathName == NULL) {
        logError("Path name is required.");
        return -1;
    }
    
    // plug in defaults for a DOS 3.3 .dsk image
    if (fileFormat == DiskImg::kFileFormatUnknown) {
        logError("File format is unspecified or invalid, substituting with default.\n");
        fileFormat = DiskImg::kFileFormatUnadorned;
    }
    if (physicalFormat == DiskImg::kPhysicalFormatUnknown) {
        logError("Physical format is unspecified or invalid, substituting with default.\n");
        physicalFormat = DiskImg::kPhysicalFormatSectors;
    }
    if (sectorOrder == DiskImg::kSectorOrderUnknown) {
        logError("Sector order is unspecified or invalid, substituting with default.\n");
        sectorOrder = DiskImg::kSectorOrderDOS;
    }
    if (fileSystemFormat == DiskImg::kFormatUnknown) {
        logError("File system format is unspecified or invalid, substituting with default.\n");
        fileSystemFormat = DiskImg::kFormatDOS33;
    }
    if (tracks < 0) {
        logError("Track count is unspecified or invalid, substituting with default.\n");
        tracks = 35;
    }
    if (sectors < 0) {
        logError("Sector count is unspecified or invalid, substituting with default.\n");
        sectors = 16;
    }

#if DEBUG
    printf("pathName = %s\n", SAFE(pathName));
    printf("storageName = %s\n", SAFE(storageName));
    printf("outerFormat = %d\n", outerFormat);
    printf("fileFormat = %d\n", fileFormat);
    printf("physicalFormat = %d\n", physicalFormat);
    printf("nibbleDescr = %p\n", nibbleDescr);
    printf("sectorOrder = %d\n", sectorOrder);
    printf("fileSystemFormat = %d\n", fileSystemFormat);
    printf("tracks = %ld\n", tracks);
    printf("sectors = %ld\n", sectors);
#endif // DEBUG
    
    Global::SetDebugMsgHandler(&diskImgDebugMsgHandler);
    Global::AppInit();
    DiskImg diskImg = DiskImg();
    
    // CreateImage() only takes generic formats
    DiskImg::FSFormat createFSFormat;
    switch (fileSystemFormat) {
        case DiskImg::kFormatDOS32:
        case DiskImg::kFormatDOS33:
            createFSFormat = DiskImg::kFormatGenericDOSOrd;
            break;
        case DiskImg::kFormatProDOS:
            createFSFormat = DiskImg::kFormatGenericProDOSOrd;
            break;
        case DiskImg::kFormatCPM:
            createFSFormat = DiskImg::kFormatGenericCPMOrd;
            break;
        default:
            createFSFormat = DiskImg::kFormatGenericPhysicalOrd;
            break;
    }
    DIError error;
    error = diskImg.CreateImage(pathName, storageName, outerFormat, fileFormat, physicalFormat,
                                nibbleDescr, sectorOrder, createFSFormat, tracks, sectors, false);
    if (error != kDIErrNone) {
        return -1;
    }
    
    error = diskImg.FormatImage(fileSystemFormat, volumeLabel);
    if (error != kDIErrNone) {
        return -1;
    }
    
    diskImg.CloseImage();
    
    return 0;
}
