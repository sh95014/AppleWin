//
//  DataFormatBASIC.m
//  Mariani
//
//  Created by sh95014 on 2/12/22.
//

//  Parts of this code are derived from the CiderPress project, whose copyright
//  terms are replicated below:

//  Copyright (c) 2009, CiderPress project authors
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//      * Neither the name of FaddenSoft, LLC nor the
//        names of its contributors may be used to endorse or promote products
//        derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY FaddenSoft, LLC ``AS IS'' AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL FaddenSoft, LLC BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "DataFormatBASIC.h"
#import "NSMutableString+RTF.h"
#import <Cocoa/Cocoa.h>

// should match the colors defined in BASICcolors(), but starts at 1
const RTFTextColor kDefaultColor = 1;
const RTFTextColor kLineNumColor = 2;
const RTFTextColor kKeywordColor = 3;
const RTFTextColor kCommentColor = 4;
const RTFTextColor kStringColor = 5;
const RTFTextColor kColonColor = 6;

static inline uint16_t Read16(const uint8_t** pBuf, long* pLength)
{
    uint16_t val;
    if (*pLength >= 2) {
        val = *(*pBuf)++;
        val |= *(*pBuf)++ << 8;
        *pLength -= 2;
    } else {
        // ought to throw an exception here
        assert(false);
        val = (uint16_t) -1;
    }
    return val;
}

static NSArray *BASICfonts()
{
    static dispatch_once_t onceToken;
    static NSArray *fonts;
    dispatch_once(&onceToken, ^{
        fonts = @[
            [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular],
            [NSFont systemFontOfSize:10],
        ];
    });
    return fonts;
}

static NSArray *BASICColors()
{
    static dispatch_once_t onceToken;
    static NSArray *colors;
    dispatch_once(&onceToken, ^{
        colors = @[
            [NSColor colorNamed:@"BASICDefaultColor"],
            [NSColor colorNamed:@"BASICLineNumberColor"],
            [NSColor colorNamed:@"BASICKeywordColor"],
            [NSColor colorNamed:@"BASICCommentColor"],
            [NSColor colorNamed:@"BASICStringColor"],
            [NSColor colorNamed:@"BASICColonColor"],
        ];
    });
    return colors;
}

NSString *ApplesoftBASICDataToRTF(NSData *data)
{
    static const char gApplesoftTokens[128 * 8] = {
        "END\0    FOR\0    NEXT\0   DATA\0   INPUT\0  DEL\0    DIM\0    READ\0   "
        "GR\0     TEXT\0   PR#\0    IN#\0    CALL\0   PLOT\0   HLIN\0   VLIN\0   "
        "HGR2\0   HGR\0    HCOLOR=\0HPLOT\0  DRAW\0   XDRAW\0  HTAB\0   HOME\0   "
        "ROT=\0   SCALE=\0 SHLOAD\0 TRACE\0  NOTRACE\0NORMAL\0 INVERSE\0FLASH\0  "
        "COLOR=\0 POP\0    VTAB\0   HIMEM:\0 LOMEM:\0 ONERR\0  RESUME\0 RECALL\0 "
        "STORE\0  SPEED=\0 LET\0    GOTO\0   RUN\0    IF\0     RESTORE\0&\0      "
        "GOSUB\0  RETURN\0 REM\0    STOP\0   ON\0     WAIT\0   LOAD\0   SAVE\0   "
        "DEF\0    POKE\0   PRINT\0  CONT\0   LIST\0   CLEAR\0  GET\0    NEW\0    "
        "TAB(\0   TO\0     FN\0     SPC(\0   THEN\0   AT\0     NOT\0    STEP\0   "
        "+\0      -\0      *\0      /\0      ^\0      AND\0    OR\0     >\0      "
        "=\0      <\0      SGN\0    INT\0    ABS\0    USR\0    FRE\0    SCRN(\0  "
        "PDL\0    POS\0    SQR\0    RND\0    LOG\0    EXP\0    COS\0    SIN\0    "
        "TAN\0    ATN\0    PEEK\0   LEN\0    STR$\0   VAL\0    ASC\0    CHR$\0   "
        "LEFT$\0  RIGHT$\0 MID$\0   ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  "
        "ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  "
        "ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0  ERROR\0 "
    };
    
    NSMutableString *outputString = [NSMutableString string];
    
    const uint8_t* srcPtr = (const uint8_t *)data.bytes;
    long srcLen = data.length;
    long length = srcLen;
    
    /*
     * Make sure there's enough here to get started.  We want to return an
     * "okay" result because we want this treated like a reformatted empty
     * BASIC program rather than a non-Applesoft file.
     */
    if (length < 2) {
        NSLog(@"  BAS truncated?");
        goto done;
    }
    
    const bool fUseRTF = true;
    [outputString RTFBeginWithFonts:BASICfonts() colors:BASICColors()];

    while (length > 0) {
        uint16_t nextAddr;
        uint16_t lineNum;
        bool inQuote = false;
        bool inRem = false;

        nextAddr = Read16(&srcPtr, &length);
        if (nextAddr == 0) {
            /* ProDOS sticks an extra byte on the end? */
            if (length > 1) {
                NSLog(@"  BAS ended early; len is %ld", length);
            }
            break;
        }

        /* print line number */
        [outputString RTFSetColor:kLineNumColor];
        lineNum = Read16(&srcPtr, &length);
        [outputString appendFormat:@" %u ", lineNum];

        [outputString RTFSetColor:kDefaultColor];

        /* print a line */
        while (*srcPtr != 0 && length > 0) {
            if (*srcPtr & 0x80) {
                /* token */
                switch (*srcPtr & 0x7F) {
                    case 50:  // REM
                        [outputString RTFSetColor:kCommentColor];
                        inRem = true;
                        break;
                    default:
                        [outputString RTFSetColor:kKeywordColor];
                        break;
                }
                [outputString appendFormat:@" %s ", &gApplesoftTokens[((*srcPtr) & 0x7f) << 3]];
                if (!inRem) {
                    [outputString RTFSetColor:kDefaultColor];
                }
            } else {
                /* simple character */
                if (fUseRTF) {
                    if (*srcPtr == '"' && !inRem) {
                        if (!inQuote) {
                            [outputString RTFSetColor:kStringColor];
                            [outputString appendCharacter:*srcPtr];
                        } else {
                            [outputString appendCharacter:*srcPtr];
                            [outputString RTFSetColor:kDefaultColor];
                        }
                        inQuote = !inQuote;
                    } else if (*srcPtr == ':' && !inRem && !inQuote) {
                        [outputString RTFSetColor:kColonColor];
                        [outputString appendCharacter:*srcPtr];
                        [outputString RTFSetColor:kDefaultColor];
                    } else if (inRem && *srcPtr == '\r') {
                        [outputString RTFNewPara];
                    } else {
                        [outputString appendCharacter:*srcPtr];
                    }
                } else {
                    if (inRem && *srcPtr == '\r') {
                        [outputString appendString:@"\r\n"];
                    } else {
                        [outputString appendCharacter:*srcPtr];
                    }
                }
            }

            srcPtr++;
            length--;
        }

        if (inQuote || inRem)
            [outputString RTFSetColor:kDefaultColor];
        inQuote = inRem = false;

        srcPtr++;
        length--;

        if (!length) {
            NSLog(@"  BAS truncated in mid-line");
            break;
        }

        [outputString RTFNewPara];
    }

done:
    [outputString RTFEnd];
    
    return outputString;
}

NSString *IntegerBASICDataToRTF(NSData *data)
{
    static const char* const gIntegerTokens[128] = {
        "HIMEM:",   "<EOL>",    "_ ",       ":",
        "LOAD ",    "SAVE ",    "CON ",     "RUN ",
        "RUN ",     "DEL ",     ",",        "NEW ",
        "CLR ",     "AUTO ",    ",",        "MAN ",
        "HIMEM:",   "LOMEM:",   "+",        "-",
        "*",        "/",        "=",        "#",
        ">=",       ">",        "<=",       "<>",
        "<",        "AND ",     "OR ",      "MOD ",

        "^ ",       "+",        "(",        ",",
        "THEN ",    "THEN ",    ",",        ",",
        "\"",       "\"",       "(",        "!",
        "!",        "(",        "PEEK ",    "RND ",
        "SGN ",     "ABS ",     "PDL ",     "RNDX ",
        "(",        "+",        "-",        "NOT ",
        "(",        "=",        "#",        "LEN(",
        "ASC( ",    "SCRN( ",   ",",        "(",

        "$",        "$",        "(",        ",",
        ",",        ";",        ";",        ";",
        ",",        ",",        ",",        "TEXT ",
        "GR ",      "CALL ",    "DIM ",     "DIM ",
        "TAB ",     "END ",     "INPUT ",   "INPUT ",
        "INPUT ",   "FOR ",     "=",        "TO ",
        "STEP ",    "NEXT ",    ",",        "RETURN ",
        "GOSUB ",   "REM ",     "LET ",     "GOTO ",

        "IF ",      "PRINT ",   "PRINT ",   "PRINT ",
        "POKE ",    ",",        "COLOR= ",  "PLOT ",
        ",",        "HLIN ",    ",",        "AT ",
        "VLIN ",    ",",        "AT ",      "VTAB ",
        "=",        "=",        ")",        ")",
        "LIST ",    ",",        "LIST ",    "POP ",
        "NODSP ",   "NODSP ",   "NOTRACE ", "DSP ",
        "DSP ",     "TRACE ",   "PR# ",     "IN# "
    };

    NSMutableString *outputString = [NSMutableString string];
    
    const uint8_t* srcPtr = (const uint8_t *)data.bytes;
    long srcLen = data.length;
    long length = srcLen;

    const bool fUseRTF = true;

    [outputString RTFBeginWithFonts:BASICfonts() colors:BASICColors()];

    /*
     * Make sure there's enough here to get started.  We want to return an
     * "okay" result because we want this treated like a reformatted empty
     * BASIC program rather than a non-Integer file.
     */
    if (length < 2) {
        NSLog(@"  INT truncated?");
        [outputString appendString:@"\r\n"];
        goto done;
    }

    while (length > 0) {
        uint8_t lineLen;
        uint16_t lineNum;
        bool trailingSpace;
        bool newTrailingSpace = false;

        /* pull the length byte, which we sanity-check */
        lineLen = *srcPtr++;
        length--;
        if (lineLen == 0) {
            NSLog(@"  INT found zero-length line?");
            break;
        }

        /* line number */
        [outputString RTFSetColor:kLineNumColor];
        lineNum = Read16(&srcPtr, &length);
        [outputString appendFormat:@"%5u ", lineNum];
        [outputString RTFSetColor:kDefaultColor];

        trailingSpace = true;
        while (*srcPtr != 0x01 && length > 0) {
            if (*srcPtr == 0x28) {
                /* start of quoted text */
                [outputString RTFSetColor:kStringColor];
                [outputString appendCharacter:'"'];
                length--;
                while (*++srcPtr != 0x29 && length > 0) {
                    /* escape chars, but let Ctrl-D and Ctrl-G through */
                    if (fUseRTF && *srcPtr != 0x84 && *srcPtr != 0x87)
                        [outputString appendCharacter:(*srcPtr & 0x7f)];
                    else
                        [outputString appendFormat:@"%c", *srcPtr & 0x7f];
                    length--;
                }
                if (*srcPtr != 0x29) {
                    NSLog(@"  INT ended while in a string constant");
                    break;
                }
                [outputString appendCharacter:'"'];
                [outputString RTFSetColor:kDefaultColor];
                srcPtr++;
                length--;
            } else if (*srcPtr == 0x5d) {
                /* start of REM statement, run to EOL */
                [outputString RTFSetColor:kCommentColor];
                [outputString appendFormat:@"%sREM ", trailingSpace ? "" : " "];
                length--;
                while (*++srcPtr != 0x01) {
                    if (fUseRTF)
                        [outputString appendCharacter:(*srcPtr & 0x7f)];
                    else
                        [outputString appendFormat:@"%c", *srcPtr & 0x7f];
                    length--;
                }
                [outputString RTFSetColor:kDefaultColor];
                if (*srcPtr != 0x01) {
                    NSLog(@"  INT ended while in a REM statement");
                    break;
                }
            } else if (*srcPtr >= 0xb0 && *srcPtr <= 0xb9) {
                /* start of integer constant */
                srcPtr++;
                length--;
                if (length < 2) {
                    NSLog(@"  INT ended while in an integer constant");
                    break;
                }
                int val;
                val = Read16(&srcPtr, &length);
                [outputString appendFormat:@"%d", val];
            } else if (*srcPtr >= 0xc1 && *srcPtr <= 0xda) {
                /* start of variable name */
                while ((*srcPtr >= 0xc1 && *srcPtr <= 0xda) ||
                       (*srcPtr >= 0xb0 && *srcPtr <= 0xb9))
                {
                    /* note no RTF-escaped chars in this range */
                    [outputString appendFormat:@"%c", *srcPtr & 0x7f];
                    srcPtr++;
                    length--;
                }
            } else if (*srcPtr < 0x80) {
                /* found a token; try to get the whitespace right */
                /* (maybe should've left whitespace on the ends of tokens
                    that are always followed by whitespace...?) */
                const char* token;
                token = gIntegerTokens[*srcPtr];
                if (*srcPtr == 0x03)    // colon
                    [outputString RTFSetColor:kColonColor];
                else
                    [outputString RTFSetColor:kKeywordColor];
                if ((token[0] >= 0x21 && token[0] <= 0x3f) || *srcPtr < 0x12) {
                    /* does not need leading space */
                    [outputString appendFormat:@"%s", token];
                } else {
                    /* needs leading space; combine with prev if it exists */
                    if (trailingSpace)
                        [outputString appendFormat:@"%s", token];
                    else
                        [outputString appendFormat:@" %s", token];
                }
                if (token[strlen(token)-1] == ' ')
                    newTrailingSpace = true;
                [outputString RTFSetColor:kDefaultColor];
                srcPtr++;
                length--;
            } else {
                /* should not happen */
                NSLog(@"  INT unexpected value 0x%02x at byte %ld",
                    *srcPtr, srcPtr - (const uint8_t *)data.bytes);

                /* skip past it and keep trying */
                srcPtr++;
                length--;
            }

            trailingSpace = newTrailingSpace;
            newTrailingSpace = false;
        } /*while line*/

        /* skip past EOL token */
        if (*srcPtr != 0x01 && length > 0) {
            NSLog(@"bailing");     // must've failed during processing
            goto bail;
        }
        srcPtr++;
        length--;

        [outputString RTFNewPara];
    }

done:
    [outputString RTFEnd];

bail:
    return outputString;
}
