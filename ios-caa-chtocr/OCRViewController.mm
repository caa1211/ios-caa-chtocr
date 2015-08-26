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

@end

@implementation OCRViewController

#define MaxDimension 800

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.ocrImageView.alignTop = YES;
    self.ocr = [[YOCREngine alloc]init];
    self.ocr.delegate = self;
    
    _labelBoundsArray_image = [[NSMutableArray alloc] init];
    _labelBoundsArray_screen = [[NSMutableArray alloc] init];
    _selectLabelBounds = [[NSMutableArray alloc] init];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _sourceImage = [UIImage imageNamed:@"testImages/003.png"];
    
    _sourceImage = [self unifyImage:_sourceImage];
    
    self.ocrImageView.image = _sourceImage;
    
    _labelBoundsArray_image = [self.ocr getLabelBounds:_sourceImage];
    [_labelBoundsArray_screen removeAllObjects];
    [_selectLabelBounds removeAllObjects];
    
    for (NSString * boundString in _labelBoundsArray_image) {
        CGRect rect = CGRectFromString(boundString);
        rect = [self coordinatesImageToScreen:rect byImage: _sourceImage];
        
        [_labelBoundsArray_screen addObject:NSStringFromCGRect(rect)];
        
        UIView *rectangle = [[UIView alloc] initWithFrame:rect];
        rectangle.alpha = 0.5;
        rectangle.backgroundColor = [UIColor redColor];
        [self.ocrImageView addSubview:rectangle];
    }
}


-(void) viewDidLayoutSubviews{
 
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    _pointCurrent = [touch locationInView:self.view];
    self.drawView.image = [[UIImage alloc] init];
    [_selectLabelBounds removeAllObjects];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint pointNext = [touch locationInView:self.view];
    UIGraphicsBeginImageContext(self.drawView.frame.size);
    [self.drawView.image drawInRect:CGRectMake(0, 0, self.drawView.frame.size.width, self.drawView.frame.size.height)];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 18.0);
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), 0.6, 0.6, 0.7, 0.6);
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), _pointCurrent.x, _pointCurrent.y);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), pointNext.x, pointNext.y);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    self.drawView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    _pointCurrent = pointNext;
    
    [self checkPointInLabelBounds:_pointCurrent];
    
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
    NSInteger w = image.size.width;
    CGFloat scale = w /  self.ocrImageView.frame.size.width;
    return CGRectMake(sourceRect.origin.x/scale, sourceRect.origin.y/scale, sourceRect.size.width/scale,sourceRect.size.height/scale);
}

- (CGRect) coordinatesScreenToImage:(CGRect)sourceRect byImage:(UIImage *) image {
    NSInteger w = image.size.width;
    CGFloat scale = w /  self.ocrImageView.frame.size.width;
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
}
-(void) progressOCR:(NSInteger)progress{
    NSLog(@"=========progress %f==================", progress);
}
-(void) finishOCR:(NSArray *)subStrings image:(UIImage*)image{
    NSString *combinedStr = @"";
    for (NSString *str in subStrings){
        if (![str isEqualToString:@""]) {
            combinedStr = [NSString stringWithFormat:@"%@ %@",combinedStr,str];
        }
    }
    self.debugLabel.text = combinedStr;
}

-(void) failedOCR: (OCRERRROR)errorCode {
    self.debugLabel.text = @"[no drawn bounds]";
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
