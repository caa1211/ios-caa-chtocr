//
//  Typerighter.m
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/27/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "Typerighter.h"

@implementation Typerighter

+ (NSMutableArray *) googleTypeRighterSync:(NSString *)keyword {
    NSMutableArray *resAry = [[NSMutableArray alloc]init];
    NSInteger maxShowingNum = 5;
    NSString* queryKeyword =[keyword stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *agentString = @"Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X; en-us) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53";
    NSString *url =[NSString stringWithFormat:@"https://www.google.com.tw/search?q=%@&ie=UTF-8&oe=UTF-8",queryKeyword];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                                    [NSURL URLWithString:url]];
    
    NSData *data = [ NSURLConnection sendSynchronousRequest:request returningResponse: nil error: nil ];
    
    NSString *returnData = [[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];
    //NSLog(@"%@", returnData);
    
    OCGumboDocument *doc = [[OCGumboDocument alloc] initWithHTMLString:returnData];
    OCQueryObject *brs = doc.Query(@"._Bmc").children(@"a");
    
    for(OCGumboElement *item in brs){
        if (resAry.count > maxShowingNum -1) {
            break;
        }
        //NSLog(@"===========%@================",  item.text());
        [resAry addObject:item.text()];
    }
    return resAry;
}


+ (void) googleTypeRighter:(NSString *)keyword completion: (void(^)(NSMutableArray *result, NSError *error))completion {
    
    dispatch_queue_t queryQueue = dispatch_queue_create("queryQueue", nil);
    
    dispatch_async(queryQueue, ^{
        
        NSMutableArray* resAry = [Typerighter googleTypeRighterSync:keyword];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            completion(resAry, nil);
        });
        
    });
    
    
 }
@end
