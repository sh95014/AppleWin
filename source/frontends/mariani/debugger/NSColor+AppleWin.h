//
//  NSColor+AppleWin.h
//  Mariani
//
//  Created by sh95014 on 5/30/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

enum NSColorModeAppleWin {
    NSColorModeAppleWinColor,           // SCHEME_COLOR
    NSColorModeAppleWinMonochrome,      // SCHEME_MONO
    NSColorModeAppleWinBlackAndWhite,   // SCHEME_BW
};

enum NSColorTypeMariani {
    NSColorTypeConsoleOutputDefault,
    NSColorTypeConsoleOutputDefaultBackground,
    NSColorTypeConsoleInputDefault,
    NSColorTypeConsoleInputDefaultBackground,
    NSColorTypeBreakpoint,
    NSColorTypeBreakpointBackground,
    NSColorTypeBookmark,
    NSColorTypeBookmarkBackground,
    NSColorTypeDisassemblerAddress,
    NSColorTypeDisassemblerOpcode,
    NSColorTypeDisassemblerMnemonic,
    NSColorTypeDisassemblerOperand,
    NSColorTypeDisassemblerImmediatePrefix,
    NSColorTypeDisassemblerImmediateValue,
    NSColorTypeDisassemblerSymbol,
    NSColorTypeDisassemblerTargetOffset,
    NSColorTypeDisassemblerParenthesis,
    NSColorTypeDisassemblerHexPrefix,
    NSColorTypeDisassemblerOperator,
    NSColorTypeDisassemblerSeparator,
    NSColorTypeDisassemblerRegisterOperand,
    NSColorTypeDisassemblerImmediateDecimal,
    NSColorTypeDisassemblerBranchDirection,
    NSColorTypeDisassemblerImmediateChar,
    NSColorTypeDisassemblerImmediateCharControl,
    NSColorTypeDisassemblerImmediateCharHigh,
    NSColorTypeDisassemblerHighlighted,
    NSColorTypeDisassemblerHighlightedBackground,
    NSColorTypeDisassemblerBackground1,
    NSColorTypeDisassemblerBackground2,
    NSColorTypeRegisterCharacterValue,
    NSColorTypeRegisterLabel,
    NSColorTypeRegisterValue,
    NSColorTypeRegistersBackground,
    NSColorTypePSRegister,
    NSColorTypeAnnunciator,
    NSColorTypeAnnunciatorBackground,
    NSColorTypeSwitchesBackground,
    NSColorTypeSwitch,
    NSColorTypeSwitchAddress,
    NSColorTypeSwitchLabel,
    NSColorTypeSwitchLabelWrite,
    NSColorTypeSwitchBackground,
};

@interface NSColor (AppleWin)

+ (NSColor *)colorFromCOLORREF:(uint32_t)cr;
+ (NSColor *)colorFromCOLORREF:(uint32_t)cr mode:(NSColorModeAppleWin)mode;

// See DebugColors_e for valid types
+ (NSColor *)colorForType:(NSColorTypeMariani)type;

@end

NS_ASSUME_NONNULL_END
