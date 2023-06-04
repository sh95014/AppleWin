//
//  DataFormatBASIC.h
//  Mariani
//
//  Created by sh95014 on 2/12/22.
//

#ifndef DATA_FORMAT_BASIC_H
#define DATA_FORMAT_BASIC_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSString *ApplesoftBASICDataToRTF(NSData *data);
NSString *IntegerBASICDataToRTF(NSData *data);

#ifdef __cplusplus
}
#endif

#endif /* DATA_FORMAT_BASIC_H */
