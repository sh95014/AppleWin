//
//  NSMutableString+RTF.m
//  Mariani
//
//  Created by sh95014 on 2/12/22.
//

//  Parts of this code are derived from the CiderPress project, whose copyright
//  terms are replicated below:

//  Copyright (c) 2009, CiderPress project authors
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//      * Neither the name of FaddenSoft, LLC nor the
//        names of its contributors may be used to endorse or promote products
//        derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY FaddenSoft, LLC ``AS IS'' AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL FaddenSoft, LLC BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "NSMutableString+RTF.h"
#import <objc/runtime.h>
#import <Cocoa/Cocoa.h>

@interface NSMutableStringRTFIVars : NSObject
@property (assign, nonatomic) RTFTextColor rtfTextColor;
+ (NSMutableStringRTFIVars *)fetch:(id)targetInstance;
@end

@implementation NSMutableStringRTFIVars

@synthesize rtfTextColor;

+ (NSMutableStringRTFIVars*)fetch:(id)targetInstance
{
    static void *compactFetchIVarKey = &compactFetchIVarKey;
    NSMutableStringRTFIVars *ivars = objc_getAssociatedObject(targetInstance, &compactFetchIVarKey);
    if (ivars == nil) {
        ivars = [[NSMutableStringRTFIVars alloc] init];
        objc_setAssociatedObject(targetInstance, &compactFetchIVarKey, ivars, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return ivars;
}

@end

@implementation NSMutableString (RTF)

- (RTFTextColor)rtfTextColor {
    return [NSMutableStringRTFIVars fetch:self].rtfTextColor;
}

- (void)setRtfTextColor:(RTFTextColor)textColor {
    [NSMutableStringRTFIVars fetch:self].rtfTextColor = textColor;
}

- (void)appendCharacter:(unichar)character {
    [self appendFormat:@"%c", character];
}

static NSString *RTFFontFamily(NSFont *font)
{
    NSFontDescriptorSymbolicTraits traits = font.fontDescriptor.symbolicTraits;
    
    if (traits & NSFontDescriptorTraitMonoSpace) {
        return @"modern";
    }
    else if (traits & NSFontDescriptorClassScripts) {
        return @"script";
    }
    else if (traits & NSFontDescriptorClassOrnamentals) {
        return @"decor";
    }
    else if (traits & NSFontDescriptorClassSymbolic) {
        return @"tech";
    }
    else if (traits & NSFontDescriptorClassSansSerif) {
        return @"swiss";
    }
    else if (traits & (NSFontDescriptorClassOldStyleSerifs |
                       NSFontDescriptorClassTransitionalSerifs |
                       NSFontDescriptorClassModernSerifs |
                       NSFontDescriptorClassClarendonSerifs |
                       NSFontDescriptorClassSlabSerifs |
                       NSFontDescriptorClassFreeformSerifs)) {
        return @"roman";
    }
    return @"nil";
}

- (void)RTFBeginWithFonts:(NSArray *)fonts colors:(NSArray *)colors {
    NSString *rtfHdrStart =
@"{\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033\\deflangfe1033{";
    
    NSString *rtfHdrFontTableStart =
    @"\\fonttbl";
    
    NSString *rtfHdrFontTableFormat =
    @"{\\f%d\\f%@\\fprq%d\\fcharset%d %@;}";
    
    NSString *rtfHdrFontTableEnd =
    @"}\r\n";

    NSString *rtfColorTableStart =
@"{\\colortbl;";
    
    NSString *rtfColorTableFormat =
    @"\\red%.0f\\green%.0f\\blue%.0f;";
    
    NSString *rtfColorTableEnd =
    @"}\r\n";

    NSString *rtfHdrEndFormat =
@"\\viewkind4\\uc1\\pard\\f0\\fs%.0f ";

    [self setString:rtfHdrStart];
    
    [self appendString:rtfHdrFontTableStart];
    NSInteger i = 0;
    for (NSFont *font in fonts) {
        [self appendFormat:rtfHdrFontTableFormat,
            i++,
            RTFFontFamily(font),
            (font.fontDescriptor.symbolicTraits & NSFontDescriptorTraitMonoSpace) ? 1 : 2,
            (font.fontDescriptor.symbolicTraits & NSFontDescriptorClassSymbolic) ? 2 : 0,
            font.fontName
        ];
    }
    [self appendString:rtfHdrFontTableEnd];
    
    [self appendString:rtfColorTableStart];
    NSColorSpace *colorSpace = [NSColorSpace deviceRGBColorSpace];
    for (NSColor *color in colors) {
        NSColor *c = [color colorUsingColorSpace:colorSpace];
        [self appendFormat:rtfColorTableFormat,
            c.redComponent * 255, c.greenComponent * 255, c.blueComponent * 255];
    }
    [self appendString:rtfColorTableEnd];
    
    [self appendFormat:rtfHdrEndFormat, [NSFont systemFontSize] * 2];
    
    [self setRtfTextColor:kColorNone];
}

- (void)RTFSetColor:(RTFTextColor)textColor {
    RTFTextColor currentColor = [self rtfTextColor];
    if (currentColor != textColor) {
        [self appendFormat:@"\\cf%d ", textColor];
        [self setRtfTextColor:textColor];
    }
}

- (void)RTFNewPara {
    [self appendString:@"\\par\r\n"];
}

- (void)RTFEnd {
    [self appendFormat:@"}\r\n%c", '\0'];
}

@end
