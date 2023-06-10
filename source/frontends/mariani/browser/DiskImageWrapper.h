//
//  DiskImageWrapper.h
//  Mariani
//
//  Created by sh95014 on 1/8/22.
//

#import <Foundation/Foundation.h>
#import "DiskImg.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiskImageWrapper : NSObject

- (instancetype)initWithPath:(NSString *)path diskImg:(DiskImgLib::DiskImg *)diskImg;

@property (readonly) NSString *path;
@property (readonly) DiskImgLib::DiskImg *diskImg;

@end

NS_ASSUME_NONNULL_END
