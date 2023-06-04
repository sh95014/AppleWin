//
//  HexDigitFormatter.m
//  Mariani
//
//  Created by sh95014 on 6/2/23.
//

#import "HexDigitFormatter.h"

@interface HexDigitFormatter ()

@property (assign) NSUInteger maxLength;
@property (strong) NSCharacterSet *hexCharacterSet;

@end

@implementation HexDigitFormatter

- (id)initWithMaxLength:(NSUInteger)maxLength {
    if ((self = [super init]) != nil) {
        self.maxLength = maxLength;
        self.hexCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    }
    return self;
}

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**)newString errorDescription:(NSString**)error {
    NSUInteger length = partialString.length;
    if (length > self.maxLength) {
        return NO;
    }
    else if (length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:partialString];
        if (![scanner scanCharactersFromSet:self.hexCharacterSet intoString:nil] || ![scanner isAtEnd]) {
            return NO;
        }
    }
    return YES;
}

- (NSString *)stringForObjectValue:(id)obj {
    if ([obj isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)obj;
        return [NSString stringWithFormat:@"%0*X", (int)self.maxLength, number.unsignedIntValue];
    }
    return nil;
}

- (BOOL)getObjectValue:(out id  _Nullable __autoreleasing *)obj forString:(NSString *)string errorDescription:(out NSString * _Nullable __autoreleasing *)error {
    if (obj != nil) {
        NSScanner *scanner = [NSScanner scannerWithString:string];
        unsigned int n;
        if ([scanner scanHexInt:&n]) {
            *obj = @(n);
        }
        return YES;
    }
    return NO;
}

@end
