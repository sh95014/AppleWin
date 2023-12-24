//
//  CharacterMappings.mm
//  Mariani
//
//  Created by sh95014 on 12/23/23.
//

#import "CharacterMappings.h"

#import "StdAfx.h"
#import "Common.h"

// Maps character values to codepoints in the Print Char 21 font

static NSArray *inverseUppercaseCharacters = @[
    // inverse “@ABC…MNO”
    @"\uE140", @"\uE141", @"\uE142", @"\uE143", @"\uE144", @"\uE145", @"\uE146", @"\uE147",
    @"\uE148", @"\uE149", @"\uE14A", @"\uE14B", @"\uE14C", @"\uE14D", @"\uE14E", @"\uE14F",
];

static NSArray *inverseUppercaseCharacters2 = @[
    // inverse “`”PQR…]^_”
    @"\uE150", @"\uE151", @"\uE152", @"\uE153", @"\uE154", @"\uE155", @"\uE156", @"\uE157",
    @"\uE158", @"\uE159", @"\uE15A", @"\uE15B", @"\uE15C", @"\uE15D", @"\uE15E", @"\uE15F",
];

static NSArray *inversePunctuationCharacters = @[
    // inverse “ !"…-./”
    @"\uE120", @"\uE121", @"\uE122", @"\uE123", @"\uE124", @"\uE125", @"\uE126", @"\uE127",
    @"\uE128", @"\uE129", @"\uE12A", @"\uE12B", @"\uE12C", @"\uE12D", @"\uE12E", @"\uE12F",
];

static NSArray *inverseDigitCharacters = @[
    // inverse “012…=>?”
    @"\uE130", @"\uE131", @"\uE132", @"\uE133", @"\uE134", @"\uE135", @"\uE136", @"\uE137",
    @"\uE138", @"\uE139", @"\uE13A", @"\uE13B", @"\uE13C", @"\uE13D", @"\uE13E", @"\uE13F",
];

static NSArray *uppercaseCharacters = @[
    // “@AB…MNO”
    @"\u0040", @"\u0041", @"\u0042", @"\u0043", @"\u0044", @"\u0045", @"\u0046", @"\u0047",
    @"\u0048", @"\u0049", @"\u004A", @"\u004B", @"\u004C", @"\u004D", @"\u004E", @"\u004F",
];

static NSArray *uppercaseCharacters2 = @[
    // “PQR…]^_”
    @"\u0050", @"\u0051", @"\u0052", @"\u0053", @"\u0054", @"\u0055", @"\u0056", @"\u0057",
    @"\u0058", @"\u0059", @"\u005A", @"\u005B", @"\u005C", @"\u005D", @"\u005E", @"\u005F",
];

static NSArray *punctuationCharacters = @[
    // “ !"…-./”
    @"SP",     @"\u0021", @"\u0022", @"\u0023", @"\u0024", @"\u0025", @"\u0026", @"\u0027",
    @"\u0028", @"\u0029", @"\u002A", @"\u002B", @"\u002C", @"\u002D", @"\u002E", @"\u002F",
];

static NSArray *digitCharacters = @[
    // “012…=>?”
    @"\u0030", @"\u0031", @"\u0032", @"\u0033", @"\u0034", @"\u0035", @"\u0036", @"\u0037",
    @"\u0038", @"\u0039", @"\u003A", @"\u003B", @"\u003C", @"\u003D", @"\u003E", @"\u003F",
];

static NSArray *lowercaseCharacters = @[
    // “`ab…mno”
    @"\u0060", @"\u0061", @"\u0062", @"\u0063", @"\u0064", @"\u0065", @"\u0066", @"\u0067",
    @"\u0068", @"\u0069", @"\u006A", @"\u006B", @"\u006C", @"\u006D", @"\u006E", @"\u006F",
];

static NSArray *lowercaseCharacters2 = @[
    // “pqr…}~▦”
    @"\u0070", @"\u0071", @"\u0072", @"\u0073", @"\u0074", @"\u0075", @"\u0076", @"\u0077",
    @"\u0078", @"\u0079", @"\u007A", @"\u007B", @"\u007C", @"\u007D", @"\u007E", @"\uE07F",
];

static NSArray *mouseTextCharacters = @[
    @"\uE080", @"\uE081", @"\uE082", @"\uE083", @"\uE084", @"\uE085", @"\uE011", @"\uE012",
    @"\uE088", @"\uE089", @"\uE08A", @"\uE08B", @"\uE08C", @"\uE08D", @"\uE08E", @"\uE08F",
];

static NSArray *mouseTextCharacters2 = @[
    @"\uE090", @"\uE091", @"\uE092", @"\uE093", @"\uE094", @"\uE095", @"\uE096", @"\uE097",
    @"\uE098", @"\uE099", @"\uE09A", @"\uE09B", @"\uE09C", @"\uE09D", @"\uE09E", @"\uE09F",
];

static NSArray *inverseLowercaseCharacters = @[
    // inverse “`ab…mno”
    @"\uE160", @"\uE161", @"\uE162", @"\uE163", @"\uE164", @"\uE165", @"\uE166", @"\uE167",
    @"\uE168", @"\uE169", @"\uE16A", @"\uE16B", @"\uE16C", @"\uE16D", @"\uE16E", @"\uE16F",
];

static NSArray *inverseLowercaseCharacters2 = @[
    // inverse “`ab…mno”
    @"\uE170", @"\uE171", @"\uE172", @"\uE173", @"\uE174", @"\uE175", @"\uE176", @"\uE177",
    @"\uE178", @"\uE179", @"\uE17A", @"\uE17B", @"\uE17C", @"\uE17D", @"\uE17E", @"\uE17F",
];

static NSArray *uppercaseCharacters2_P82 = @[
    // “PQR…ЩЧ_”
    @"\u0050", @"\u0051", @"\u0052", @"\u0053", @"\u0054", @"\u0055", @"\u0056", @"\u0057",
    @"\u0058", @"\u0059", @"\u005A", @"\uE9F8", @"\u005C", @"\uE9F9", @"\uE9F7", @"\u005F",
];

static NSArray *uppercaseCharacters2_P8M = @[
    // “PQR…]Ч_”
    @"\u0050", @"\u0051", @"\u0052", @"\u0053", @"\u0054", @"\u0055", @"\u0056", @"\u0057",
    @"\u0058", @"\u0059", @"\u005A", @"\u005B", @"\u005C", @"\u005D", @"\uE9F7", @"\u005F",
];

static NSArray *uppercaseCharacters_P82 = @[
    // “ЮAB…MNO”
    @"\uE9FE", @"\u0041", @"\u0042", @"\u0043", @"\u0044", @"\u0045", @"\u0046", @"\u0047",
    @"\u0048", @"\u0049", @"\u004A", @"\u004B", @"\u004C", @"\u004D", @"\u004E", @"\u004F",
];

static NSArray *uppercaseCyrillicCharacters = @[
    // “@АБ…МНО”
    @"\u0040", @"\uE9E0", @"\uE9E1", @"\uE9F6", @"\uE9E4", @"\uE9E5", @"\uE9F4", @"\uE9E3",
    @"\uE9F5", @"\uE9E8", @"\uE9E9", @"\uE9EA", @"\uE9EB", @"\uE9EC", @"\uE9ED", @"\uE9EE",
];

static NSArray *uppercaseCyrillicCharacters2 = @[
    // “ПЯР…]^■”
    @"\uE9EF", @"\uE9FF", @"\uE9F0", @"\uE9F1", @"\uE9F2", @"\uE9F3", @"\uE9E6", @"\uE9E2",
    @"\uE9FC", @"\uE9FA", @"\uE9E7", @"\u005B", @"\uE9F9", @"\u005D", @"\u005E", @"\uE120",
];

static NSArray *uppercaseCyrillicCharacters2_P8M = @[
    // “ПЯР…]^■”
    @"\uE9EF", @"\uE9FF", @"\uE9F0", @"\uE9F1", @"\uE9F2", @"\uE9F3", @"\uE9E6", @"\uE9E2",
    @"\uE9FC", @"\uE9FA", @"\uE9E7", @"\u005B", @"\u005C", @"\u005D", @"\u005E", @"\uE120",
];

NSArray *defaultCharacterMapping = nil;
NSArray *alternateCharacterMapping = nil;

void ConfigureCharacterMappings(void) {
    NSMutableArray *mapping = [NSMutableArray array];
    
    if (g_Apple2Type == A2TYPE_PRAVETS82) {
        // Pravets 82, CHARSET82.bmp
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2_P82];
        [mapping addObjectsFromArray:punctuationCharacters];
        [mapping addObjectsFromArray:digitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters_P82];
        [mapping addObjectsFromArray:uppercaseCharacters2_P82];
        [mapping addObjectsFromArray:uppercaseCyrillicCharacters];
        [mapping addObjectsFromArray:uppercaseCyrillicCharacters2];
    }
    else if (g_Apple2Type == A2TYPE_PRAVETS8M) {
        // Pravets 8M, CHARSET8M.bmp
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2_P82];
        [mapping addObjectsFromArray:punctuationCharacters];
        [mapping addObjectsFromArray:digitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters_P82];
        [mapping addObjectsFromArray:uppercaseCharacters2_P8M];
        [mapping addObjectsFromArray:uppercaseCyrillicCharacters];
        [mapping addObjectsFromArray:uppercaseCyrillicCharacters2_P8M];
    }
    else if (IsAppleIIeOrAbove(g_Apple2Type)) {
        // Regular //e, CHARSET4.BMP top group
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2];
        [mapping addObjectsFromArray:punctuationCharacters];
        [mapping addObjectsFromArray:digitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2];
        [mapping addObjectsFromArray:lowercaseCharacters];
        [mapping addObjectsFromArray:lowercaseCharacters2];
    }
    else {
        // ][ or ][+, CHARSET4.BMP bottom group
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2];
        [mapping addObjectsFromArray:punctuationCharacters];
        [mapping addObjectsFromArray:digitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2];
        [mapping addObjectsFromArray:punctuationCharacters];
        [mapping addObjectsFromArray:digitCharacters];
    }
    
    defaultCharacterMapping = [NSArray arrayWithArray:mapping];
    alternateCharacterMapping = nil;
    
    if (IsAppleIIeOrAbove(g_Apple2Type)) {
        [mapping removeAllObjects];
        
        // MouseText //e, CHARSET4.BMP middle group
        [mapping addObjectsFromArray:inverseUppercaseCharacters];
        [mapping addObjectsFromArray:inverseUppercaseCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:mouseTextCharacters];
        [mapping addObjectsFromArray:mouseTextCharacters2];
        [mapping addObjectsFromArray:inversePunctuationCharacters];
        [mapping addObjectsFromArray:inverseDigitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2];
        [mapping addObjectsFromArray:punctuationCharacters];
        [mapping addObjectsFromArray:digitCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters];
        [mapping addObjectsFromArray:uppercaseCharacters2];
        [mapping addObjectsFromArray:lowercaseCharacters];
        [mapping addObjectsFromArray:lowercaseCharacters2];
        
        alternateCharacterMapping = [NSArray arrayWithArray:mapping];
    }
}
