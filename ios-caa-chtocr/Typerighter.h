//
//  Typerighter.h
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/27/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCGumbo/OCGumbo+Query.h"

@interface Typerighter : NSObject
+ (void)googleTypeRighter:(NSString *)keyword completion: (void(^)(NSMutableArray *result, NSError *error))completion;
+ (NSMutableArray *) googleTypeRighterSync:(NSString *)keyword;
@end
