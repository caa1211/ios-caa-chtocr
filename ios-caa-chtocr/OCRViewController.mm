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
@property (weak, nonatomic) IBOutlet UIImageViewAligned *ocrImageView;
@property (strong, nonatomic) YOCREngine *ocr;
@property (weak, nonatomic) IBOutlet UIImageView *drawView;
@property (assign, nonatomic) CGPoint pointCurrent;
@property (strong, nonatomic) NSMutableArray *labelBoundsArray_image;
@property (strong, nonatomic) NSMutableArray *labelBoundsArray_screen;
@property (strong, nonatomic) NSMutableArray *selectLabelBounds;
@property (strong, nonatomic) UIImage* sourceImage;
@property (weak, nonatomic) IBOutlet UILabel *debugLabel;
@property (weak, nonatomic) IBOutlet UIView *ocrWrapperView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

@implementation OCRViewController

#define MaxDimension 800

- (id)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _sourceImage = image;
    }
    
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.ocrImageView.alignTop = YES;
    self.ocrImageView.alignLeft = YES;
    self.ocr = [[YOCREngine alloc]init];
    self.ocr.delegate = self;
    
    _labelBoundsArray_image = [[NSMutableArray alloc] init];
    _labelBoundsArray_screen = [[NSMutableArray alloc] init];
    _selectLabelBounds = [[NSMutableArray alloc] init];
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _sourceImage = nil;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    _sourceImage = [self unifyImage:_sourceImage];
    
    self.ocrImageView.image = _sourceImage;
    
    _labelBoundsArray_image = [self.ocr getLabelBounds:_sourceImage];
    [_labelBoundsArray_screen removeAllObjects];
    [_selectLabelBounds removeAllObjects];
    
    for (NSString * boundString in _labelBoundsArray_image) {
        CGRect rect = CGRectFromString(boundString);
        rect = [self coordinatesImageToScreen:rect byImage: _sourceImage];
        // rect = [self.ocrImageView convertRect:rect toView:self.drawView];
        
        [_labelBoundsArray_screen addObject:NSStringFromCGRect(rect)];
        
        UIView *rectangle = [[UIView alloc] initWithFrame:rect];
        rectangle.alpha = 0.3;
        rectangle.backgroundColor = [UIColor redColor];
        [self.ocrWrapperView addSubview:rectangle];
    }
}


-(void) viewDidLayoutSubviews{
 
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    _pointCurrent = [touch locationInView:self.ocrWrapperView];
    self.drawView.image = [[UIImage alloc] init];
    [_selectLabelBounds removeAllObjects];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint pointNext = [touch locationInView:self.ocrWrapperView];

    if(![self isPoint:pointNext insideOfRect:self.ocrWrapperView.bounds] ) {
        return;
    }
    UIGraphicsBeginImageContext(self.drawView.frame.size);
    [self.drawView.image drawInRect:CGRectMake(0, 0, self.drawView.frame.size.width, self.drawView.frame.size.height)];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 18.0);
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), 0.5, 0.5, 0.7, 0.6);
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), _pointCurrent.x, _pointCurrent.y);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), pointNext.x, pointNext.y);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    self.drawView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    _pointCurrent = pointNext;
    
    CGPoint brushT = pointNext;
    brushT.y = brushT.y + 6;
    CGPoint brushB = pointNext;
    brushB.y = brushT.y - 6;
    [self checkPointInLabelBounds:brushT];
    [self checkPointInLabelBounds:brushB];
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [_ocr ocrWithImage:_sourceImage inBounds:_selectLabelBounds];
}

-(void) checkPointInLabelBounds: (CGPoint)point {

     for (NSString *boundString in _labelBoundsArray_screen) {
         CGRect rect = CGRectFromString(boundString);
         CGRect imageRect = [self coordinatesScreenToImage:rect byImage:_sourceImage];
         NSString *imageRectStr = NSStringFromCGRect(imageRect);
         if([self isPoint:_pointCurrent insideOfRect:rect] && ![self isStoredBounds:imageRectStr]){
             [_selectLabelBounds addObject:imageRectStr];
         }
     }
}


-(BOOL)isStoredBounds: (NSString*)rectStr {
    // Image coordinate
    for (NSString * boundString in _selectLabelBounds) {
        if ([boundString isEqualToString:rectStr]) {
            return YES;
        }
    }
    return NO;
}


-(BOOL)isPoint:(CGPoint)point insideOfRect:(CGRect)rect
{
    if ( CGRectContainsPoint(rect,point))
        return  YES;// inside
    else
        return  NO;// outside
}

- (CGRect) coordinatesImageToScreen:(CGRect)sourceRect byImage:(UIImage *) image {
    CGFloat scaleW = image.size.width /  self.ocrImageView.frame.size.width;
    CGFloat scaleH = image.size.height /  self.ocrImageView.frame.size.height;
    CGFloat scale = MAX(scaleW, scaleH);
    return CGRectMake(sourceRect.origin.x/scale, sourceRect.origin.y/scale, sourceRect.size.width/scale,sourceRect.size.height/scale);
}

- (CGRect) coordinatesScreenToImage:(CGRect)sourceRect byImage:(UIImage *) image {
    CGFloat scaleW = image.size.width /  self.ocrImageView.frame.size.width;
    CGFloat scaleH = image.size.height /  self.ocrImageView.frame.size.height;
    CGFloat scale = MAX(scaleW, scaleH);
    return CGRectMake(sourceRect.origin.x*scale, sourceRect.origin.y*scale, sourceRect.size.width*scale,sourceRect.size.height*scale);
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

-(void) startOCR {
    self.progressView.progress = 0;
    self.debugLabel.text = @"";
}
-(void) progressOCR:(NSInteger)progress{
   NSLog(@"=========progress %ld==================", progress);
   self.progressView.progress = (float)progress/100;
}
-(void) finishOCR:(NSArray *)subStrings image:(UIImage*)image{
    NSString *combinedStr = @"";
    for (NSString *str in subStrings){
        if (![str isEqualToString:@""]) {
            combinedStr = [NSString stringWithFormat:@"%@ %@",combinedStr,str];
        }
    }
    self.debugLabel.text = combinedStr;
    self.progressView.progress = 1;
}

-(void) failedOCR: (OCRERRROR)errorCode {
    self.debugLabel.text = @"[no drawn bounds]";
    self.progressView.progress = 0;
}


-(void) cancelledOCR{}




/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
