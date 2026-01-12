//
//  NSImage+SFSymbols.m
//  Mariani
//
//  Created by sh95014 on 1/12/26.
//

#import "NSImage+SFSymbols.h"
#import <AppKit/AppKit.h>

@implementation NSImage (SFSymbols)

+ (NSImageSymbolConfiguration *)marianiLargeSymbolConfiguration {
    static NSImageSymbolConfiguration *symbolConfiguration = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        symbolConfiguration = [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleLarge];
    });
    return symbolConfiguration;
}

+ (NSImage *)largeImageWithSymbolName:(NSString *)name {
    if (@available(macOS 13.0, *)) {
        NSImage *image = [NSImage imageWithSymbolName:name variableValue:0];
        return [image imageWithSymbolConfiguration:[[self class] marianiLargeSymbolConfiguration]];
    }
    return nil;
}

+ (NSImage *)largeImageWithSystemSymbolName:(NSString *)name {
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:@""];
    return [image imageWithSymbolConfiguration:[[self class] marianiLargeSymbolConfiguration]];
}

@end
