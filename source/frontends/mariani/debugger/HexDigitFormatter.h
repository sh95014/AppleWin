//
//  HexDigitFormatter.h
//  Mariani
//
//  Created by sh95014 on 6/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HexDigitFormatter : NSFormatter

- (id)initWithMaxLength:(NSUInteger)maxLength;

@end

NS_ASSUME_NONNULL_END
