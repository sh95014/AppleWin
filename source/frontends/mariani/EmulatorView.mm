//
//  EmulatorView.mm
//  Mariani
//
//  Created by sh95014 on 12/29/21.
//

#import "EmulatorView.h"
#import "Carbon/Carbon.h"
#import "UserDefaults.h"

#import "wincompat.h"
#import "linux/keyboardbuffer.h"
#import "linux/paddle.h"

#import "StdAfx.h"
#import "Core.h"
#import "CardManager.h"
#import "MouseInterface.h"

@interface EmulatorView ()

@property BOOL forceCapsLock;
@property NSTrackingRectTag trackingRectTag;

@end

@implementation EmulatorView

enum {
    ASCII_NUL           = 0x00,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗@⦘
    ASCII_BS            = 0x08,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗H⦘
    ASCII_HT            = 0x09,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗I⦘
    ASCII_LF            = 0x0A,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗J⦘
    ASCII_VT            = 0x0B,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗K⦘
    ASCII_CR            = 0x0D,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗M⦘
    ASCII_NAK           = 0x15,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗U⦘
    ASCII_ESC           = 0x1B,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗[⦘
    ASCII_FS            = 0x1C,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗\⦘
    ASCII_GS            = 0x1D,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗]⦘
    ASCII_RS            = 0x1E,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗^⦘
    ASCII_US            = 0x1F,  // ⦗𝙲𝚃𝚁𝙻⦘-⦗-⦘
    ASCII_SP            = 0x20,
    ASCII_QUOTE         = 0x27,  // ⦗'⦘
    ASCII_BACKSLASH     = 0x5C,  // ⦗\⦘
    ASCII_DEL           = 0x7F,
};

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        self.forceCapsLock = YES;
        self.trackingRectTag = [self addTrackingRect:self.bounds owner:self userData:NULL assumeInside:YES];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)viewDidMoveToWindow {
    [self.window setAcceptsMouseMovedEvents:YES];
    [self.window makeFirstResponder:self];
}

- (void)updateTrackingAreas {
    [NSCursor unhide];
    [self removeTrackingRect:self.trackingRectTag];
    self.trackingRectTag = [self addTrackingRect:self.bounds owner:self userData:NULL assumeInside:YES];
}

// Going by the Apple ][ Reference Manual, the rules are basically:
// - the number keys are modified by ⦗𝚂𝙷𝙸𝙵𝚃⦘ only
// - the letter keys are modified by ⦗𝙲𝚃𝚁𝙻⦘ only (not true for //e)
// - 0 is unmodified by ⦗𝙲𝚃𝚁𝙻⦘ or ⦗𝚂𝙷𝙸𝙵𝚃⦘, but that's not relevant to us
// - special keys like ⦗←⦘ or ⦗→⦘ are sent as control characters
- (void)keyDown:(NSEvent *)event {
    NSInteger ch = -1;
    
    switch (event.keyCode) {
        case kVK_ANSI_KeypadEnter:
        case kVK_Return:
            ch = ASCII_CR;
            break;
        case kVK_Delete:
            // A macOS user might be accustomed to using [delete] key as backspace, so
            // leaving that as an option for now ([delete]->left arrow, [option]+[delete]
            // to delete).
            if (![UserDefaults sharedInstance].mapDeleteKeyToLeftArrow ||
                event.modifierFlags & NSEventModifierFlagOption) {
                ch = ASCII_DEL;
                break;
            }
            // fallthrough
        case kVK_LeftArrow:
            ch = ASCII_BS;
            break;
        case kVK_RightArrow:
            ch = ASCII_NAK;
            break;
        case kVK_UpArrow:
            ch = ASCII_VT;
            break;
        case kVK_DownArrow:
            ch = ASCII_LF;
            break;
        case kVK_Escape:
            ch = ASCII_ESC;
            break;
        case kVK_Tab:
            ch = ASCII_HT;
            break;
        case kVK_ANSI_Keypad0:   // fallthrough
        case kVK_ANSI_Keypad1:   // fallthrough
        case kVK_ANSI_Keypad2:   // fallthrough
        case kVK_ANSI_Keypad3:   // fallthrough
        case kVK_ANSI_Keypad4:   // fallthrough
        case kVK_ANSI_Keypad6:   // fallthrough
        case kVK_ANSI_Keypad7:   // fallthrough
        case kVK_ANSI_Keypad8:   // fallthrough
        case kVK_ANSI_Keypad9: { // fallthrough
            if ([[UserDefaults sharedInstance].gameController isEqualToString:GameControllerNumericKeypad]) {
                [self.numericKeyDelegate emulatorView:self numericKeyDown:[event.charactersIgnoringModifiers characterAtIndex:0]];
                return;
            }
            // fallthrough
        }
        default: {
            unichar raw = [event.charactersIgnoringModifiers characterAtIndex:0];
            if (event.modifierFlags & NSEventModifierFlagControl) {
                // for the following, ⦗𝙲𝚃𝚁𝙻⦘-⦗𝚂𝙷𝙸𝙵𝚃⦘-[key] = ⦗𝙲𝚃𝚁𝙻⦘-[key]
                if (raw >= 'A' && raw <= 'Z') {
                    ch = raw - 0x40;  // A → ⦗𝙲𝚃𝚁𝙻⦘-A
                }
                else if (raw >= 'a' && raw <= 'z') {
                    ch = raw - 0x60;  // a → ⦗𝙲𝚃𝚁𝙻⦘-A
                }
                else if (raw == '-' || raw == '_') {
                    ch = ASCII_US;
                }
                else if (raw == '2' || raw == '@') {
                    ch = ASCII_NUL;
                }
                else if (raw == '6' || raw == '^') {
                    ch = ASCII_RS;
                }
                else if (raw == '[' || raw == '{') {
                    ch = ASCII_ESC;
                }
                else if (raw == ASCII_BACKSLASH || raw == '|') {
                    ch = ASCII_FS;
                }
                else if (raw == ']' || raw == '}') {
                    ch = ASCII_GS;
                }
                // for the following, ⦗𝙲𝚃𝚁𝙻⦘-⦗𝚂𝙷𝙸𝙵𝚃⦘-[key] = ⦗𝚂𝙷𝙸𝙵𝚃⦘-[key]
                else {
                    ch = raw;
                }
            }
            else if (raw >= ASCII_SP && raw < ASCII_DEL) {
                if (self.forceCapsLock || (event.modifierFlags & NSEventModifierFlagCapsLock)) {
                    ch = toupper(raw);
                }
                else {
                    ch = raw;
                }
            }
            break;
        }
    }
    if (ch >= ASCII_NUL) {
        addKeyToBuffer(ch);
    }
    else {
        NSLog(@"Ignored key code 0x%02X", event.keyCode);
    }
}

- (void)keyUp:(NSEvent *)event {
    switch (event.keyCode) {
        case kVK_ANSI_Keypad0:   // fallthrough
        case kVK_ANSI_Keypad1:   // fallthrough
        case kVK_ANSI_Keypad2:   // fallthrough
        case kVK_ANSI_Keypad3:   // fallthrough
        case kVK_ANSI_Keypad4:   // fallthrough
        case kVK_ANSI_Keypad6:   // fallthrough
        case kVK_ANSI_Keypad7:   // fallthrough
        case kVK_ANSI_Keypad8:   // fallthrough
        case kVK_ANSI_Keypad9: { // fallthrough
            if ([[UserDefaults sharedInstance].gameController isEqualToString:GameControllerNumericKeypad]) {
                [self.numericKeyDelegate emulatorView:self numericKeyUp:[event.charactersIgnoringModifiers characterAtIndex:0]];
            }
            break;
        }
    }
}

- (void)flagsChanged:(NSEvent *)event
{
    switch (event.keyCode) {
        case kVK_CapsLock:
            self.forceCapsLock = NO;
            break;
        case kVK_Option:
            if (event.modifierFlags & NSEventModifierFlagOption) {
                Paddle::setButtonPressed(Paddle::ourOpenApple);
            }
            else {
                Paddle::setButtonReleased(Paddle::ourOpenApple);
            }
            break;
        case kVK_RightOption:
            if (event.modifierFlags & NSEventModifierFlagOption) {
                Paddle::setButtonPressed(Paddle::ourSolidApple);
            }
            else {
                Paddle::setButtonReleased(Paddle::ourSolidApple);
            }
            break;
        default:
            break;
    }
}

- (void)addStringToKeyboardBuffer:(NSString *)string {
    addTextToBuffer(string.UTF8String);
}

- (void)mouseDown:(NSEvent *)event {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CardManager & cardManager = GetCardMgr();

    if (cardManager.IsMouseCardInstalled() && cardManager.GetMouseCard()->IsActiveAndEnabled()) {
        cardManager.GetMouseCard()->SetButton(BUTTON0, BUTTON_DOWN);
    }
}

- (void)mouseUp:(NSEvent *)event {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CardManager & cardManager = GetCardMgr();

    if (cardManager.IsMouseCardInstalled() && cardManager.GetMouseCard()->IsActiveAndEnabled()) {
        cardManager.GetMouseCard()->SetButton(BUTTON0, BUTTON_UP);
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CardManager & cardManager = GetCardMgr();

    if (cardManager.IsMouseCardInstalled() && cardManager.GetMouseCard()->IsActiveAndEnabled()) {
        cardManager.GetMouseCard()->SetButton(BUTTON1, BUTTON_DOWN);
    }
}

- (void)rightMouseUp:(NSEvent *)event {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CardManager & cardManager = GetCardMgr();

    if (cardManager.IsMouseCardInstalled() && cardManager.GetMouseCard()->IsActiveAndEnabled()) {
        cardManager.GetMouseCard()->SetButton(BUTTON1, BUTTON_UP);
    }
}

- (void)mouseMoved:(NSEvent *)event {
    CardManager & cardManager = GetCardMgr();

    if (cardManager.IsMouseCardInstalled() && cardManager.GetMouseCard()->IsActiveAndEnabled()) {
        int iX, iMinX, iMaxX;
        int iY, iMinY, iMaxY;
        cardManager.GetMouseCard()->GetXY(iX, iMinX, iMaxX, iY, iMinY, iMaxY);
        
        long dx, dy;
        CGSize viewSize = self.bounds.size;
        if (iMaxX - iMinX == 32767 && iMaxY - iMinY == 32767) {
            // we can't tell where the emulated mouse pointer is, so relative
            // motion is the best we can do.
            // see SDLFrame::ProcessMouseMotion for details
            dx = lround(event.deltaX);
            dy = lround(event.deltaY);
        }
        else {
            // translate the absolute (view-relative) position of the pointer
            // into a relative motion so that the emulated mouse pointer can
            // match where the real mouse pointer is.
            CGPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
            
            const int sizeX = iMaxX - iMinX;
            const int sizeY = iMaxY - iMinY;
            const int newX = iMinX + (int)lround((location.x / viewSize.width) * sizeX);
            const int newY = iMinY + (int)lround((1 - location.y / viewSize.height) * sizeY);
            
            dx = newX - iX;
            dy = newY - iY;
        }
        
        int outOfBoundsX, outOfBoundsY;
        cardManager.GetMouseCard()->SetPositionRel(dx, dy, &outOfBoundsX, &outOfBoundsY);
    }
}

- (void)mouseDragged:(NSEvent *)event {
    [self mouseMoved:event];
}

- (void)mouseEntered:(NSEvent *)event {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    CardManager & cardManager = GetCardMgr();
    if (cardManager.IsMouseCardInstalled() && cardManager.GetMouseCard()->IsActiveAndEnabled()) {
        [NSCursor hide];
    }
}

- (void)mouseExited:(NSEvent *)event {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    CardManager & cardManager = GetCardMgr();
    if (cardManager.IsMouseCardInstalled() && cardManager.GetMouseCard()->IsActiveAndEnabled()) {
        [NSCursor unhide];
    }
}

@end
