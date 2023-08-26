//
//  ScriptCommands.mm
//  Mariani
//
//  Created by sh95014 on 8/25/23.
//

#import "AppDelegate.h"
#import "PreferencesViewController.h"

#import "StdAfx.h"
#import "CardManager.h"
#import "Core.h"
#import "Disk.h"

@interface RebootCommand : NSScriptCommand
@end

@interface InsertCommand : NSScriptCommand
@end

@interface TypeCommand : NSScriptCommand
@end

@interface ScreenshotCommand : NSScriptCommand
@end

@class Drive;

@interface Slot : NSObject
@property (readonly) NSString *card;
@property (readonly) Drive *drives;
@property (assign) UINT index;
@property (assign) SS_CARDTYPE cardType;
@end

@interface Drive : NSObject
@property (assign) int index;
@property (weak) Slot *slot;
@end

@interface AppDelegate (Scripting)
@property (readonly) NSArray *slots;
@end

#pragma mark -

@implementation RebootCommand

- (id)performDefaultImplementation {
    [theAppDelegate rebootEmulatorAction:self];
    return nil;
}

@end

#pragma mark -

@implementation InsertCommand

- (id)performDefaultImplementation {
    NSString *filename = [self directParameter];
    std::string cppFilename(filename.UTF8String);
    Drive* drive = [[self evaluatedArguments] valueForKey:@"drive"];
    CardManager &cardManager = GetCardMgr();
    Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(drive.slot.index));
    card->InsertDisk(drive.index, cppFilename, IMAGE_USE_FILES_WRITE_PROTECT_STATUS, IMAGE_DONT_CREATE);
    return nil;
}

@end

#pragma mark -

@implementation TypeCommand

- (id)performDefaultImplementation {
    [theAppDelegate.emulatorVC type:[self directParameter]];
    return nil;
}

@end

#pragma mark -

@implementation ScreenshotCommand

- (id)performDefaultImplementation {
    [theAppDelegate.emulatorVC saveScreenshot:YES];
    return nil;
}

@end

#pragma mark -

@implementation Drive

- (id)initWithIndex:(int)index slot:(Slot *)slot {
    if ((self = [super init]) != nil) {
        self.index = index;
        self.slot = slot;
    }
    return self;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    return [[NSIndexSpecifier alloc] initWithContainerClassDescription:(NSScriptClassDescription *)self.slot.classDescription
                                                    containerSpecifier:nil
                                                                   key:@"drives"
                                                                 index:self.index];
}

- (NSString *)disk {
    CardManager &cardManager = GetCardMgr();
    Disk2InterfaceCard *card = dynamic_cast<Disk2InterfaceCard*>(cardManager.GetObj(self.slot.index));
    return [NSString stringWithUTF8String:card->GetFullDiskFilename(self.index).c_str()];
}

@end

#pragma mark -

@implementation Slot

- (id)initWithIndex:(UINT)index card:(SS_CARDTYPE)cardType {
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

- (NSArray *)drives {
    NSMutableArray *drives = [NSMutableArray array];
    CardManager &cardManager = GetCardMgr();
    if (cardManager.QuerySlot(self.index) == CT_Disk2) {
        for (int index = DRIVE_1; index < NUM_DRIVES; index++) {
            Drive *drive = [[Drive alloc] initWithIndex:index slot:self];
            [drives addObject:drive];
        }
    }
    return drives;
}

@end

#pragma mark -

@implementation AppDelegate (Scripting)

- (NSArray *)slots {
    NSMutableArray *slots = [NSMutableArray array];
    CardManager &manager = GetCardMgr();
    for (UINT slot = SLOT1; slot < NUM_SLOTS; slot++) {
        SS_CARDTYPE card = manager.QuerySlot(slot);
        [slots addObject:[[Slot alloc] initWithIndex:slot card:card]];
    }
    return slots;
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key {
    return [key isEqualToString:@"slots"];
}

@end
