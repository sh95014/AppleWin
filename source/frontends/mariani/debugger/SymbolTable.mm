//
//  SymbolTable.mm
//  Mariani
//
//  Created by sh95014 on 6/2/23.
//

#import "SymbolTable.h"
#import "StdAfx.h"
#import "Debugger_Types.h"
#import "Debugger_Symbols.h"
#import <boost/algorithm/string/predicate.hpp>

#define SORT_SYMBOL_TABLE

const NSNotificationName SymbolTableDidChangeNotification = @"SymbolTableDidChangeNotification";

@implementation SymbolTableItem
@end

#ifdef SORT_SYMBOL_TABLE
@interface SymbolTable ()

@property (strong) NSMutableArray<SymbolTableItem *> *sortedTable;

@end

@implementation NSString (CaseInsensitivity)

- (BOOL)hasCaseInsensitivePrefix:(NSString *)prefix {
    const NSStringCompareOptions options = NSAnchoredSearch | NSCaseInsensitiveSearch;
    NSRange prefixRange = [self rangeOfString:prefix options:options];
    return prefixRange.location == 0 && prefixRange.length > 0;
}

@end
#endif // SORT_SYMBOL_TABLE

@implementation SymbolTable

+ (SymbolTable *)sharedTable {
    static dispatch_once_t onceToken;
    static SymbolTable *singleton;
    dispatch_once(&onceToken, ^{
        singleton = [[SymbolTable alloc] init];
    });
    return singleton;
}

#ifdef SORT_SYMBOL_TABLE
- (id)init {
    if ((self = [super init]) != nil) {
        [self copySymbolTable];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:SymbolTableDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            [self copySymbolTable];
        }];
    }
    return self;
}

- (void)copySymbolTable {
    self.sortedTable = [NSMutableArray array];
    
    for (NSInteger table = 0; table < NUM_SYMBOL_TABLES; table++) {
        for (auto iter = g_aSymbols[table].begin(); iter != g_aSymbols[table].end(); iter++) {
            SymbolTableItem *item = [[SymbolTableItem alloc] init];
            item.address = iter->first;
#ifdef DEBUG
            item.symbol = [NSString stringWithFormat:@"%s ($%04X)", iter->second.c_str(), iter->first];
#else
            item.symbol = [NSString stringWithUTF8String:iter->second.c_str()];
#endif
            [self.sortedTable addObject:item];
        }
    }
    [self.sortedTable sortUsingComparator:^NSComparisonResult(SymbolTableItem  * _Nonnull item1, SymbolTableItem  * _Nonnull item2) {
        return [item1.symbol caseInsensitiveCompare:item2.symbol];
    }];
}

- (NSUInteger)totalNumberOfSymbols {
    return self.sortedTable.count;
}

- (SymbolTableItem *)firstItemWithPrefix:(NSString *)prefix {
    for (SymbolTableItem *item in self.sortedTable) {
        if ([item.symbol hasCaseInsensitivePrefix:prefix]) {
            return item;
        }
    }
    return nil;
}

- (SymbolTableItem *)itemAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.sortedTable.count) {
        return self.sortedTable[index];
    }
    return nil;
}

- (NSInteger)indexOfSymbol:(NSString *)symbol {
    return [self.sortedTable indexOfObjectPassingTest:^BOOL(SymbolTableItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL found = ([item.symbol caseInsensitiveCompare:symbol] == NSOrderedSame);
        *stop = found;
        return found;
    }];
}

#else // SORT_SYMBOL_TABLE

- (NSUInteger)totalNumberOfSymbols {
    NSUInteger total = 0;
    for (NSInteger table = 0; table < NUM_SYMBOL_TABLES; table++) {
        total += g_aSymbols[table].size();
    }
    return total;
}

- (SymbolTableItem *)firstItemWithPrefix:(NSString *)prefix {
    std::string cppPrefix(prefix.UTF8String);
    for (NSInteger table = 0; table < NUM_SYMBOL_TABLES; table++) {
        for (auto iter = g_aSymbols[table].begin(); iter != g_aSymbols[table].end(); iter++) {
            if (iter->second.length() > cppPrefix.length() && boost::istarts_with(iter->second, cppPrefix)) {
                SymbolTableItem *item = [[SymbolTableItem alloc] init];
                item.address = iter->first;
                item.symbol = [NSString stringWithUTF8String:iter->second.c_str()];
                return item;
            }
        }
    }
    return nil;
}

- (SymbolTableItem *)itemAtIndex:(NSInteger)index {
    for (NSInteger table = 0; table < NUM_SYMBOL_TABLES; table++) {
        const NSInteger tableSize = g_aSymbols[table].size();
        if (index < tableSize) {
            auto iter = g_aSymbols[table].begin();
            std::advance(iter, index);
            SymbolTableItem *item = [[SymbolTableItem alloc] init];
            item.address = iter->first;
            item.symbol = [NSString stringWithUTF8String:iter->second.c_str()];
            return item;
        }
        index -= tableSize;
    }
    return nil;
}

- (NSInteger)indexOfSymbol:(NSString *)symbol {
    NSUInteger index = 0;
    std::string cppSymbol(symbol.UTF8String);
    for (NSInteger table = 0; table < NUM_SYMBOL_TABLES; table++) {
        for (auto iter = g_aSymbols[table].begin(); iter != g_aSymbols[table].end(); iter++) {
            if (iter->second == cppSymbol) {
                return index;
            }
            index++;
        }
    }
    return NSNotFound;
}
#endif // SORT_SYMBOL_TABLE

@end
