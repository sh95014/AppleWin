//
//  ScriptCommands.h
//  Mariani
//
//  Created by sh95014 on 8/25/23.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface RebootCommand : NSScriptCommand

@end

@interface Slot : NSObject

@property (readonly) NSString *card;

@end

@interface AppDelegate (Scripting)

@property (readonly) NSArray *slots;

@end

NS_ASSUME_NONNULL_END
