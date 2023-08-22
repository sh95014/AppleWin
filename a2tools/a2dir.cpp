//
//  a2dir.cpp
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

int main(int argc, const char * argv[]) {
    const char *imageFileName = NULL;
    
    for (int i = 1; i < argc; i++) {
        if (equalString(argv[i], "-i")) {
            imageFileName = getString(argc, argv, ++i);
            logErrorIf(imageFileName == NULL, "Image file name expected after -i.\n");
        }
    }
    
    if (imageFileName == NULL) {
        logError("Image file name is required.\n");
        return -1;
    }
    
    Global::SetDebugMsgHandler(&diskImgDebugMsgHandler);
    Global::AppInit();
    DiskImg diskImg = DiskImg();
    
    if (diskImg.OpenImage(imageFileName, '/', true) == kDIErrNone &&
        diskImg.AnalyzeImage() == kDIErrNone) {
#if DEBUG
        printf("outerFormat = %d\n", diskImg.GetOuterFormat());
        printf("fileFormat = %d\n", diskImg.GetFileFormat());
        printf("physicalFormat = %d\n", diskImg.GetPhysicalFormat());
        printf("nibbleDescr = %p\n", diskImg.GetNibbleDescr());
        printf("sectorOrder = %d\n", diskImg.GetSectorOrder());
        printf("fileSystemFormat = %d\n", diskImg.GetFSFormat());
        printf("tracks = %ld\n", diskImg.GetNumTracks());
        printf("sectors = %d\n", diskImg.GetNumSectPerTrack());
#endif // DEBUG
        
        return 0;
    }
    
    return -1;
}
