//
//  SymbolTable.h
//  Mariani
//
//  Created by sh95014 on 6/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSNotificationName SymbolTableDidChangeNotification;

@interface SymbolTableItem : NSObject
@property (strong) NSString *symbol;
@property NSUInteger address;
@end

@interface SymbolTable : NSObject

+ (SymbolTable *)sharedTable;

- (NSUInteger)totalNumberOfSymbols;
- (SymbolTableItem *)firstItemWithPrefix:(NSString *)prefix;
- (SymbolTableItem *)itemAtIndex:(NSInteger)index;
- (NSInteger)indexOfSymbol:(NSString *)symbol;

@end

NS_ASSUME_NONNULL_END
