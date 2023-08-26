//
//  ScriptCommands.mm
//  Mariani
//
//  Created by sh95014 on 8/25/23.
//

#import "ScriptCommands.h"
#import "AppDelegate.h"
#import "PreferencesViewController.h"

#import "StdAfx.h"
//#import "Card.h"
#import "CardManager.h"
//#import "Common.h"
#import "Core.h"

@interface RebootCommand : NSScriptCommand
@end

@implementation RebootCommand

- (id)performDefaultImplementation {
    [theAppDelegate rebootEmulatorAction:self];
    return nil;
}

@end

#pragma mark -

@interface Slot : NSObject

@property (readonly) NSString *card;

@property (assign) NSInteger index;
@property (assign) SS_CARDTYPE cardType;

@end

@implementation Slot

- (id)initWithIndex:(NSInteger)index card:(SS_CARDTYPE)cardType {
    if ((self = [super init]) != nil) {
        self.index = index;
        self.cardType = cardType;
    }
    return self;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptClassDescription* appDesc = (NSScriptClassDescription*)[NSApp classDescription];
    return [[NSIndexSpecifier alloc] initWithContainerClassDescription:appDesc
                                                    containerSpecifier:nil
                                                                   key:@"slots"
                                                                 index:self.index - SLOT1];
}

- (NSString *)card {
    NSDictionary *cardNames = [PreferencesViewController localizedCardNameMap];
    return cardNames[@(self.cardType)];
}

@end

#pragma mark -

@interface AppDelegate (Scripting)

@property (readonly) NSArray *slots;

@end

@implementation AppDelegate (Scripting)

- (NSArray *)slots {
    NSMutableArray *slots = [NSMutableArray array];
    CardManager &manager = GetCardMgr();
    for (int slot = SLOT1; slot < NUM_SLOTS; slot++) {
        SS_CARDTYPE card = manager.QuerySlot(slot);
        [slots addObject:[[Slot alloc] initWithIndex:slot card:card]];
    }
    return slots;
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key {
    return [key isEqualToString:@"slots"];
}

@end
