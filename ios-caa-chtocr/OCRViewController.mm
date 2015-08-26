//
//  OCRViewController.m
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/27/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "OCRViewController.h"
#import "YOCREngine.h"
#import "UIImageViewAligned.h"
#import "ImageTools.h"

@interface OCRViewController () <YOCREngineDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *debugImageView;
@property (weak, nonatomic) IBOutlet UIImageViewAligned *ocrImageView;
@property (strong, nonatomic) YOCREngine *ocr;
@end

@implementation OCRViewController

#define MaxDimension 800

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.ocrImageView.alignTop = YES;
    self.ocr = [[YOCREngine alloc]init];
    self.ocr.delegate = self;
    
}


-(void) viewDidLayoutSubviews{
 
    UIImage* sourceImage = [UIImage imageNamed:@"testImages/027.jpg"];
    
    sourceImage = [self unifyImage:sourceImage];
    self.ocrImageView.image = sourceImage;
    
    NSMutableArray *boundsArray = [self.ocr getLabelBounds:sourceImage];
    
    for (NSString * boundString in boundsArray) {
        CGRect rect = CGRectFromString(boundString);
        rect = [self coordinatesImageToScreen:rect byImage: sourceImage];
        
        UIView *rectangle = [[UIView alloc] initWithFrame:rect];
        rectangle.alpha = 0.5;
        rectangle.backgroundColor = [UIColor redColor];
        [self.ocrImageView addSubview:rectangle];
    }
}

- (CGRect) coordinatesImageToScreen:(CGRect)sourceRect byImage:(UIImage *) image {
    NSInteger w = image.size.width;
    NSInteger h = image.size.height;
    CGFloat scaleW = w /  self.ocrImageView.frame.size.width;
    CGFloat scaleH = h / self.ocrImageView.frame.size.height;
    CGFloat scale;
    if (w<h) {
        scale = scaleW;
    }else {
        scale = scaleH;
    }
    return CGRectMake(sourceRect.origin.x/scale, sourceRect.origin.y/scale, sourceRect.size.width/scale,sourceRect.size.height/scale);
}


- (UIImage *) unifyImage:(UIImage *)sourceImage{
    UIImage *image = [ImageTools imageRotatedByDegrees:[ImageTools scaleImage:sourceImage maxDimension:MaxDimension] deg:0];
    return image;
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - OCR delegate

//-(void) startOCR {}
//-(void) progressOCR:(NSInteger)progress{}
//-(void) finishOCR:(NSArray *)subStrings image:(UIImage*)image{}
//-(void) passOCRThreshold:(NSInteger)number{}
//-(void) failOCRThreshold:(NSInteger)number{}
//-(void) cancelledOCR{}
//-(void) ocrLabelCropped: (UIImage*)image{}
-(void) ocrDebugImage: (UIImage*)image{
    self.debugImageView.image = image;
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
