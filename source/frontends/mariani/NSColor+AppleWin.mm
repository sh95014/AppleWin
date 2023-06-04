//
//  NSColor+AppleWin.mm
//  Mariani
//
//  Created by sh95014 on 5/30/23.
//

#import "NSColor+AppleWin.h"

#import "StdAfx.h"
#import "Debug.h"

@implementation NSColor (AppleWin)

static NSDictionary<NSNumber *, NSNumber *> *colorTypeToAppleWinMapping = @{
    @(NSColorTypeConsoleOutputDefault) : @(FG_CONSOLE_OUTPUT),
    @(NSColorTypeConsoleOutputDefaultBackground) : @(BG_CONSOLE_OUTPUT),
    @(NSColorTypeConsoleInputDefault) : @(FG_CONSOLE_INPUT),
    @(NSColorTypeConsoleInputDefaultBackground) : @(BG_CONSOLE_INPUT),
    
    @(NSColorTypeBreakpoint) : @(FG_DISASM_BP_S_C),
    @(NSColorTypeBreakpointBackground) : @(BG_DISASM_BP_S_C),
    @(NSColorTypeBookmark) : @(FG_DISASM_BOOKMARK),
    @(NSColorTypeBookmarkBackground) : @(BG_DISASM_BOOKMARK),
    
    @(NSColorTypeDisassemblerAddress) : @(FG_DISASM_ADDRESS),
    @(NSColorTypeDisassemblerOpcode) : @(FG_DISASM_OPCODE),
    @(NSColorTypeDisassemblerSymbol) : @(FG_DISASM_SYMBOL),
    @(NSColorTypeDisassemblerMnemonic) : @(FG_DISASM_MNEMONIC),
    @(NSColorTypeDisassemblerOperand) : @(FG_DISASM_TARGET),
    @(NSColorTypeDisassemblerImmediatePrefix) : @(FG_DISASM_OPERATOR),
    @(NSColorTypeDisassemblerImmediateValue) : @(FG_DISASM_OPCODE),
    @(NSColorTypeDisassemblerTargetOffset) : @(FG_DISASM_OPCODE),
    @(NSColorTypeDisassemblerParenthesis) : @(FG_DISASM_OPERATOR),
    @(NSColorTypeDisassemblerHexPrefix) : @(FG_DISASM_OPERATOR),
    @(NSColorTypeDisassemblerOperator) : @(FG_DISASM_OPERATOR),
    @(NSColorTypeDisassemblerSeparator) : @(FG_DISASM_OPERATOR),
    @(NSColorTypeDisassemblerRegisterOperand) : @(FG_INFO_REG),
    @(NSColorTypeDisassemblerImmediateDecimal) : @(FG_DISASM_SINT8),
    @(NSColorTypeDisassemblerBranchDirection) : @(FG_DISASM_BRANCH),
    @(NSColorTypeDisassemblerImmediateChar) : @(FG_DISASM_CHAR),
    @(NSColorTypeDisassemblerImmediateCharControl) : @(FG_INFO_CHAR_LO),
    @(NSColorTypeDisassemblerImmediateCharHigh) : @(FG_INFO_CHAR_HI),
    @(NSColorTypeDisassemblerHighlighted) : @(FG_DISASM_PC_X),
    @(NSColorTypeDisassemblerBackground1) : @(BG_DISASM_1),
    @(NSColorTypeDisassemblerBackground2) : @(BG_DISASM_2),
    
    @(NSColorTypeRegisterCharacterValue) : @(FG_DISASM_CHAR),
    @(NSColorTypeRegisterLabel) : @(FG_INFO_REG),
    @(NSColorTypeRegisterValue) : @(FG_INFO_OPCODE),
    @(NSColorTypeRegistersBackground) : @(BG_DATA_1),
    @(NSColorTypePSRegister) : @(FG_INFO_TITLE),
    
    @(NSColorTypeAnnunciator) : @(FG_INFO_TITLE),
    @(NSColorTypeAnnunciatorBackground) : @(BG_INFO),
    
    @(NSColorTypeSwitchesBackground) : @(BG_INFO),
    @(NSColorTypeSwitch) : @(FG_INFO_TITLE),
    @(NSColorTypeSwitchAddress) : @(FG_DISASM_TARGET),
    @(NSColorTypeSwitchLabel) : @(FG_INFO_REG),
    @(NSColorTypeSwitchLabelWrite) : @(FG_DISASM_BP_S_X),
    @(NSColorTypeSwitchBackground) : @(BG_INFO),
};

+ (NSColor *)colorFromCOLORREF:(uint32_t)cr {
    return [NSColor colorWithRed:((cr >> 0) & 0xFF) / 255.0
                           green:((cr >> 8) & 0xFF) / 255.0
                            blue:((cr >> 16) & 0xFF) / 255.0
                           alpha:1.0];
}

+ (NSColor *)colorFromCOLORREF:(uint32_t)cr mode:(NSColorModeAppleWin)mode {
    int r = (cr >> 0) & 0xFF;
    int g = (cr >> 8) & 0xFF;
    int b = (cr >> 16) & 0xFF;
    
    switch (mode) {
        case NSColorModeAppleWinColor:
            return [NSColor colorWithRed:(r / 255.0) green:(g / 255.0) blue:(b / 255.0) alpha:1.0];
        case NSColorModeAppleWinMonochrome:
            return [[NSColor colorWithRed:(r / 255.0) green:(g / 255.0) blue:(b / 255.0) alpha:1.0] colorUsingColorSpace:[NSColorSpace genericGrayColorSpace]];
        case NSColorModeAppleWinBlackAndWhite:
            // from ConfigColorsReset() in Debugger_Color.cpp
            return ((r + g + b) / 3 > 64) ? [NSColor whiteColor] : [NSColor blackColor];
    }
}

+ (NSColor *)colorForType:(NSColorTypeMariani)type {
    NSNumber *appleWinType = colorTypeToAppleWinMapping[@(type)];
    if (appleWinType != nil) {
        return [self colorFromCOLORREF:DebuggerGetColor(appleWinType.intValue)];
    }
    return nil;
}

@end
