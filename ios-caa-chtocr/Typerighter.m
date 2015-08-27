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
//    NSString *agentString = @"Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X; en-us) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53";
    NSString *url =[NSString stringWithFormat:@"https://www.google.com.tw/search?q=%@&ie=UTF-8&oe=UTF-8",queryKeyword];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                                    [NSURL URLWithString:url]];
    
    NSData *data = [ NSURLConnection sendSynchronousRequest:request returningResponse: nil error: nil ];
    
    NSString *returnData = [[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];

    OCGumboDocument *doc = [[OCGumboDocument alloc] initWithHTMLString:returnData];
    OCQueryObject *brs = doc.Query(@"._Bmc").children(@"a");
    
    for(OCGumboElement *item in brs){
        if (resAry.count > maxShowingNum -1) {
            break;
        }
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


+ (void) ecTokenization:(NSString *)keyword completion: (void(^)(NSString *str, NSError *error))completion{

    NSString* queryKeyword =[keyword stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *url =[NSString stringWithFormat:@"http://fetchstretch.corp.sg3.yahoo.com/qlas/index.php?title=%@",queryKeyword];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                                    [NSURL URLWithString:url]];

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if (data == nil) {
             dispatch_sync(dispatch_get_main_queue(), ^{
                 completion(nil, error);
             });
         }else{
             NSString *response = [[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];
             
             NSArray *subStrings = [response componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"\n"]];
             
             NSString* resultStr = @"";
             
             for (int i=0;i<[subStrings count];i++){
                 NSString *subStr=[subStrings objectAtIndex:i];
                 
                 NSString *endStr = @"<!--";
                 if ([subStr rangeOfString:endStr].location != NSNotFound) {
                     break;
                 }
                 if ([resultStr isEqualToString:@""]) {
                     resultStr = subStr;
                 }else {
                     resultStr = [NSString stringWithFormat:@"%@ %@",resultStr, subStr];
                 }
             }
             
             NSLog(@"Rokenization Result: %@", resultStr);
             
             dispatch_sync(dispatch_get_main_queue(), ^{
                 completion(resultStr, nil);
             });
         }
     }];
}

//+(void) ecTokenization:(NSString *)keyword completion: (void(^)(NSString *str, NSError *error))completion{
//    
//    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
//    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
//    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
//    
//    [manager GET:@"http://fetchstretch.corp.sg3.yahoo.com/qlas/index.php" parameters:@{@"title": keyword} success:^(AFHTTPRequestOperation *operation, id responseObject) {
//        NSString *response = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
//        NSArray *subStrings = [response componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"\n"]];
//        
//        NSString* resultStr = @"";
//        
//        for (int i=0;i<[subStrings count];i++){
//            NSString *subStr=[subStrings objectAtIndex:i];
//            
//            NSString *endStr = @"<!--";
//            if ([subStr rangeOfString:endStr].location != NSNotFound) {
//                break;
//            }
//            if ([resultStr isEqualToString:@""]) {
//                resultStr = subStr;
//            }else {
//                resultStr = [NSString stringWithFormat:@"%@ %@",resultStr, subStr];
//            }
//        }
//        
//        NSLog(@"Rokenization Result: %@", resultStr);
//        
//        completion(resultStr, nil);
//    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//        completion(nil, error);
//        NSLog(@"Error: %@", error);
//    }];
//    
//}

@end
