//
//  NSImage+SFSymbols.h
//  Mariani
//
//  Created by sh95014 on 1/12/26.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (SFSymbols)

+ (NSImage *)largeImageWithSymbolName:(NSString *)name;
+ (NSImage *)largeImageWithSystemSymbolName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
