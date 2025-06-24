//
//  DiskImageWrapper.mm
//  Mariani
//
//  Created by sh95014 on 1/8/22.
//

#import "DiskImageWrapper.h"

using namespace DiskImgLib;

@interface DiskImageWrapper()

@property (assign) NSString *path;

@end

@implementation DiskImageWrapper {
    DiskImg *_diskImg;
}

- (instancetype)initWithPath:(NSString *)path diskImg:(DiskImgLib::DiskImg *)diskImg {
    if ((self = [super init]) != nil) {
        self.path = path;
        _diskImg = diskImg;
    }
    return self;
}

- (void)dealloc {
    delete _diskImg;
}

@end
