//
//  NSMutableString+RTF.h
//  Mariani
//
//  Created by sh95014 on 2/12/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kColorNone          = 0,
    // full colors (RGB 0 or 255)
    kColorBlack         = 1,
    kColorBlue          = 2,
    kColorCyan          = 3,
    kColorGreen         = 4,        // a little bright for white bkgnd
    kColorPink          = 5,
    kColorRed           = 6,
    kColorYellow        = 7,
    kColorWhite         = 8,
    // mixed colors
    kColorMediumBlue    = 9,
    kColorMediumAqua    = 10,
    kColorMediumGreen   = 11,
    kColorMagenta       = 12,
    kColorMediumRed     = 13,
    kColorOlive         = 14,
    kColorMediumGrey    = 15,
    kColorLightGrey     = 16,
    kColorDarkGrey      = 17,
    kColorOrange        = 18,
} RTFTextColor;

@interface NSMutableString (RTF)

- (void)appendCharacter:(unichar)character;

- (void)RTFBeginWithFonts:(NSArray *)fonts colors:(NSArray *)colors;
- (void)RTFSetColor:(RTFTextColor)colorIndex;
- (void)RTFNewPara;
- (void)RTFEnd;

@end

NS_ASSUME_NONNULL_END
