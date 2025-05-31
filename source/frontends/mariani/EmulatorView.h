//
//  EmulatorView.h
//  Mariani
//
//  Created by sh95014 on 12/29/21.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol EmulatorViewDelegate;

@interface EmulatorView : MTKView

@property (nonatomic, weak, nullable) id<EmulatorViewDelegate> numericKeyDelegate;

- (void)addStringToKeyboardBuffer:(NSString *)string;

@end

@protocol EmulatorViewDelegate <NSObject>

- (void)emulatorView:(EmulatorView *)view numericKeyDown:(unichar)key;
- (void)emulatorView:(EmulatorView *)view numericKeyUp:(unichar)key;

@end

NS_ASSUME_NONNULL_END
