//
//  DiskImageWrapper.mm
//  Mariani
//
//  Created by sh95014 on 1/8/22.
//

#import "DiskImageWrapper.h"

using namespace DiskImgLib;

@implementation DiskImageWrapper {
    NSString *_path;
    DiskImg *_diskImg;
}

- (instancetype)initWithPath:(NSString *)path diskImg:(DiskImgLib::DiskImg *)diskImg {
    if ((self = [super init]) != nil) {
        _path = path;
        _diskImg = diskImg;
    }
    return self;
}

- (void)dealloc {
    delete _diskImg;
}

@end
