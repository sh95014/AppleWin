//
//  NSFont+Mariani.m
//  Mariani
//
//  Created by sh95014 on 8/21/23.
//

#import "NSFont+Mariani.h"

@implementation NSFont (Mariani)

+ (NSFont *)myMonospacedSystemFontOfSize:(CGFloat)fontSize weight:(NSFontWeight)weight {
    if (@available(macOS 10.15, *)) {
        return [NSFont monospacedSystemFontOfSize:fontSize weight:weight];
    }
    else {
        return [NSFont systemFontOfSize:fontSize weight:weight];
    }
}

@end
