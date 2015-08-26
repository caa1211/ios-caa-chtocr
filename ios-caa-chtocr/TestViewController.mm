//
//  TestViewController.m
//  eccs
//
//  Created by Carter Chang on 8/20/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "TestViewController.h"
#import "YOCREngine.h"
#import "UIImageViewAligned.h"


@interface TestViewController () <YOCREngineDelegate>
@property (weak, nonatomic) IBOutlet UIImageViewAligned *imageView;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIView *ocrTargetView;
@property (weak, nonatomic) IBOutlet UIImageView *ocrTargetImageView;
@property (weak, nonatomic) IBOutlet UIImageView *debugImage;
@property (strong, nonatomic) YOCREngine *ocr;
@end


#if 0
#define testImage @"testImages/003.png"
#define testImage @"testImages/005.png" X
#define testImage @"testImages/006.png"
#define testImage @"testImages/007.png" X
#define testImage @"testImages/008.jpg"
#define testImage @"testImages/009.jpg"
#define testImage @"testImages/010.jpg"
#define testImage @"testImages/011.jpg"
#define testImage @"testImages/012.jpg"
#define testImage @"testImages/013.jpg"
#define testImage @"testImages/015.jpg" X
#define testImage @"testImages/018.jpg"
#define testImage @"testImages/019.jpg"
#define testImage @"testImages/020.jpg"
#define testImage @"testImages/022.jpg"
#define testImage @"testImages/023.jpg" X
#define testImage @"testImages/024.jpg" X
#define testImage @"testImages/025.jpg"
#define testImage @"testImages/026.jpg"
#endif

#define testImage @"testImages/025.jpg"

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.ocrTargetView.layer.masksToBounds = YES;
    self.ocrTargetView.layer.borderWidth = 2.0f;
    self.ocrTargetView.layer.borderColor = CGColorRetain([UIColor colorWithRed:0.845 green:0.863 blue:0.860 alpha:1].CGColor);
    
    self.ocr = [[YOCREngine alloc]init];
    self.ocr.delegate = self;
    
    UIImage *image = [UIImage imageNamed:testImage];
    self.imageView.image = image;
    self.imageView.alignTop = YES;
}


- (IBAction)onButtonClick:(id)sender {
    UIImage *image = [UIImage imageNamed:testImage];
    self.imageView.image = image;
    image = [self imageRotatedByDegrees:[self scaleImage:image maxDimension:2000] deg:0];
    
   
    [self cropByTarget:image complete:^(UIImage *cropedImage) {
        
        self.imageView.image = nil;
        
        cropedImage = [self scaleImage:cropedImage maxDimension:800];
        
        self.ocrTargetImageView.image = cropedImage;
        
//      
//        for(int i=0; i<5; i++){
//            NSLog(@"delay to ocr");
//            [NSThread sleepForTimeInterval:1.0f];
//        }
        
        if ([self.ocr testOCRThreshold:cropedImage]){
            [self.ocr ocrWithImage:cropedImage];
        }
        
    }];

}

#pragma  - OCR
- (void) startOCR{
    NSLog(@"=======startOCR==========");
}

- (void) finishOCR:(NSArray *)subStrings image:(UIImage *)image{
    NSLog(@"=============subStrings %@==============", subStrings);
}

- (void) progressOCR:(NSInteger)progress{
    NSLog(@"=======progressOCR===%ld=======", progress);
}

-(void) passOCRThreshold:(NSInteger)number {
    NSLog(@"=======passOCRThreshold===%ld=======", number);
}

-(void) failOCRThreshold:(NSInteger)number {
    NSLog(@"=======failOCRThreshold===%ld=======", number);
}

-(void) ocrLabelCropped: (UIImage*)image {
  NSLog(@"=======ocrLabelCropped=======");
  self.ocrTargetImageView.image = image;
}

-(void) ocrDebugImage: (UIImage*)image {
    NSLog(@"=======ocrLabelCropped=======");
    self.debugImage.image = image;
}



- (void) cropByTarget:(UIImage*)image complete:(void(^)(UIImage *image))completion{
    
    // This function should be run in background thread
    CGRect wrapperRect = self.view.frame;
    CGRect frameRect = self.ocrTargetView.frame;
    
    CGFloat scaleW = image.size.width / wrapperRect.size.width;
    //CGFloat scaleH = image.size.height / wrapperRect.size.height;
    
    CGRect rect = CGRectMake(
                             (frameRect.origin.x )*scaleW,
                             (frameRect.origin.y )*scaleW,
                             frameRect.size.width*scaleW,
                             (frameRect.size.height )*scaleW
                             );
    
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], rect);
    UIImage *cropedImg = [UIImage imageWithCGImage:imageRef ];
    
    CGImageRelease(imageRef);
    
    if (completion!=nil) {
        completion(cropedImg);
    }
    
}


-(UIImage*) scaleImage:(UIImage*)image maxDimension:(CGFloat)maxDimension {
    
    CGSize scaledSize = CGSizeMake(maxDimension,maxDimension);
    CGFloat scaleFactor;
    
    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    
    if (w>h) {
        scaleFactor = h/w;
        scaledSize.width = maxDimension;
        scaledSize.height = scaledSize.height*scaleFactor;
    }else {
        scaleFactor = w/h;
        scaledSize.height = maxDimension;
        scaledSize.width = scaledSize.width*scaleFactor;
    }
    UIGraphicsBeginImageContext(scaledSize);
    [image drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}


- (UIImage *)imageRotatedByDegrees:(UIImage*)oldImage deg:(CGFloat)degrees{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,oldImage.size.width, oldImage.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, (degrees * M_PI / 180));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.width, oldImage.size.height), [oldImage CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
