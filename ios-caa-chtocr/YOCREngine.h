//
//  YOCREngine.h
//  eccs
//
//  Created by Carter Chang on 8/17/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TesseractOCR/TesseractOCR.h>
#import <opencv2/videoio/cap_ios.h>
#import "CVTools.h"


typedef enum OCRERRROR : NSInteger {
    OCRERRROR_NOBOUNDS = 0
}OCRERRROR;


@protocol YOCREngineDelegate <NSObject>

-(void) startOCR;
-(void) progressOCR:(NSInteger)progress;
-(void) finishOCR:(NSString *)resultString image:(UIImage*)image;
-(void) failedOCR: (OCRERRROR)errorCode;
-(void) cancelledOCR;
-(void) ocrDebugImage:(UIImage*)image;
@end


@interface YOCREngine : NSObject
@property (nonatomic, weak) id<YOCREngineDelegate>delegate;
@property(assign, atomic) bool cancelOCR;
@property(assign, atomic) bool isOCRing;

-(NSMutableArray *) getLabelBounds:(UIImage *)image;
-(void) ocrWithImage:(UIImage *)image inBounds:(NSMutableArray*)boundsArray;
@end
