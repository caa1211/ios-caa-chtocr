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

@protocol YOCREngineDelegate <NSObject>

-(void) startOCR;
-(void) progressOCR:(NSInteger)progress;
-(void) finishOCR:(NSArray *)subStrings image:(UIImage*)image;
-(void) passOCRThreshold:(NSInteger)number;
-(void) failOCRThreshold:(NSInteger)number;
-(void) cancelledOCR;

-(void) ocrLabelCropped: (UIImage*)image;
-(void) ocrDebugImage: (UIImage*)image;

@end


@interface YOCREngine : NSObject
@property (nonatomic, weak) id<YOCREngineDelegate>delegate;
@property(assign, nonatomic) bool cancelOCR;
@property(assign, atomic) bool isOCRing;

-(void) extractTextFromImage:(UIImage*)image complete:(void(^)(UIImage *))complete;
-(void) extractTextFromCVImage:(cv::Mat)mat letterBoxes:(std::vector<cv::Rect>)letterBoxes complete:(void(^)(NSString *result, UIImage *image))complete;
-(std::vector<cv::Rect>) detectLetters:(cv::Mat)img;
-(void)ocrWithImage:(UIImage*)image;
-(NSDictionary *) testOCRThreshold:(UIImage*)image;
@end
