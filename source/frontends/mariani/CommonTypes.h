//
//  CommonTypes.h
//  Mariani
//
//  Created by sh95014 on 12/29/21.
//

#ifndef CommonTypes_h
#define CommonTypes_h

typedef struct {
    void *data;
    unsigned pixelWidth;
    unsigned pixelHeight;
    unsigned bufferWidth;
    unsigned bufferHeight;
    unsigned borderWidth;
    unsigned borderHeight;
} FrameBuffer;

// how much of the overscan area to display
#define OVERSCAN                0.1

#define TARGET_FPS              60
#define CMTIME_BASE             60000

#endif /* CommonTypes_h */
