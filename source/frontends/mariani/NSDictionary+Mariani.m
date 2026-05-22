//
//  NSDictionary+Mariani.m
//  Mariani
//
//  Created by sh95014 on 5/21/26.
//

#import "NSDictionary+Mariani.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDictionary (Mariani)

- (NSString *)stringForKey:(NSString *)key {
    id value = [self objectForKey:key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

@end

NS_ASSUME_NONNULL_END
