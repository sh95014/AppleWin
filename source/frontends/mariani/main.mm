//
//  main.mm
//  Mariani
//
//  Created by sh95014 on 12/27/21.
//

#import <Cocoa/Cocoa.h>
#import "programoptions.h"

common2::EmulatorOptions gEmulatorOptions;

int main(int argc, const char * argv[]) {
    int argCount = argc;
    if (argc > 2 &&
        strcmp(argv[argc - 2], "-NSDocumentRevisionsDebugMode") == 0 &&
        strcmp(argv[argc - 1], "YES") == 0) {
        // strip off parameters that Xcode seems to inject.
        argCount -= 2;
    }
    if (!getEmulatorOptions(argCount, argv, "macOS", gEmulatorOptions)) {
        return -1;
    }
    return NSApplicationMain(argc, argv);
}
