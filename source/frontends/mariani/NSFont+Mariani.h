//
//  NSFont+Mariani.h
//  Mariani
//
//  Created by sh95014 on 8/21/23.
//

#import <Cocoa/Cocoa.h>
#import <Availability.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFont (Mariani)

+ (NSFont *)myMonospacedSystemFontOfSize:(CGFloat)fontSize weight:(NSFontWeight)weight;

@end

NS_ASSUME_NONNULL_END
