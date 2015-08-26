//
//  ImageTools.h
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/27/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ImageTools : NSObject
+(UIImage*) scaleImage:(UIImage*)image maxDimension:(CGFloat)maxDimension;
+(UIImage *)imageRotatedByDegrees:(UIImage*)oldImage deg:(CGFloat)degrees;

@end
