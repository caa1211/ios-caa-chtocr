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
#import "Typerighter.h"
#import "NBSlideUpView.h"
#import "OCRResultView.h"
#import "ImagePickerViewController.h"
#import <CoreGraphics/CoreGraphics.h>

@interface OCRViewController () <YOCREngineDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, NBSlideUpViewDelegate, OCRResultViewDelegate>
@property (weak, nonatomic) IBOutlet UIImageViewAligned *ocrImageView;
@property (strong, nonatomic) YOCREngine *ocr;
@property (weak, nonatomic) IBOutlet UIImageView *drawView;
@property (assign, nonatomic) CGPoint pointCurrent;
@property (strong, nonatomic) NSMutableArray *labelBoundsArray_image;
@property (strong, nonatomic) NSMutableArray *labelBoundsArray_screen;
@property (strong, nonatomic) NSMutableArray *selectLabelBounds;
@property (strong, nonatomic) UIImage* sourceImage;
@property (weak, nonatomic) IBOutlet UIView *ocrWrapperView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (assign, nonatomic) BOOL isImageOCRed;
@property (assign, nonatomic) NSInteger typerRighterCount;
@property (strong, nonatomic) NSMutableArray *ocrResults; //Collected from related search
@property (weak, nonatomic) IBOutlet UIImageView *debugImageView;
@property (strong, nonatomic) NSString *ocrRawResult; // OCR raw result
@property (nonatomic, strong) NBSlideUpView *slideUpView;
@property (nonatomic, strong) OCRResultView *ocrResultView;
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
    
    self.debugImageView.hidden = YES;

    self.ocrImageView.alignTop = YES;
    self.ocrImageView.alignLeft = YES;
    self.ocr = [[YOCREngine alloc]init];
    self.ocr.delegate = self;
    
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    if (self.isImageOCRed != YES) {
        [self ocrImage];
        self.isImageOCRed = YES;
    }
    
    self.slideUpView = [[NBSlideUpView alloc] initWithSuperview:self.view viewableHeight:200];
    self.slideUpView.delegate = self;
    
    self.ocrResultView = [[OCRResultView alloc] initWithDelegate:self];
    [self.slideUpView.contentView addSubview:self.ocrResultView];
    
    
//    self.slideUpView.shouldBlockSuperviewTouchesWhileUp = YES;
//    self.slideUpView.shouldTapSuperviewToAnimateOut = YES;
    
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _sourceImage = nil;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}



-(void) initDrawingStatus {
    _typerRighterCount = 0;
    self.drawView.image = [[UIImage alloc] init];
    self.progressView.progress = 0;

}


-(void) ocrImage {

    _labelBoundsArray_image = [[NSMutableArray alloc] init];
    _labelBoundsArray_screen = [[NSMutableArray alloc] init];
    _selectLabelBounds = [[NSMutableArray alloc] init];

    if (self.ocr.isOCRing) {
        self.ocr.cancelOCR = YES;
    }
    
    [self initDrawingStatus];
    
    _sourceImage = [self unifyImage:_sourceImage];
    self.ocrImageView.image = _sourceImage;
    _labelBoundsArray_image = [self.ocr getLabelBounds:_sourceImage];
    [_labelBoundsArray_screen removeAllObjects];
    
    [[self.drawView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    NSInteger cornerRadius = 5;
    
    for (NSString * boundString in _labelBoundsArray_image) {
        CGRect rect = CGRectFromString(boundString);
        rect = [self coordinatesImageToScreen:rect byImage: _sourceImage];

        [_labelBoundsArray_screen addObject:NSStringFromCGRect(rect)];
        
        UIView *rectangle = [[UIView alloc] initWithFrame:rect];
        rectangle.alpha = 0.7;
        //rectangle.backgroundColor = [UIColor whiteColor];
        rectangle.layer.borderColor = [UIColor redColor].CGColor;
        rectangle.layer.borderWidth = 2.0f;
        rectangle.layer.cornerRadius = cornerRadius;
        [self.drawView addSubview:rectangle];
        
        UIView *rectangleFill = [[UIView alloc] initWithFrame:rect];
        rectangleFill.alpha = 0.2;
        rectangleFill.backgroundColor = [UIColor colorWithRed:1 green:0.975 blue:1.000 alpha:0.500];
        rectangleFill.layer.cornerRadius = cornerRadius;
        [self.drawView addSubview:rectangleFill];
        
    }
    
}

- (IBAction)onPanDrawView:(UIPanGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self.ocrWrapperView];
    if(sender.state == UIGestureRecognizerStateBegan){
        [self drawBegin: point];
    }else if(sender.state == UIGestureRecognizerStateChanged){
        [self drawMove: point];
    }else if(sender.state == UIGestureRecognizerStateEnded){
        [self drawEnd: point];
    }
}

-(void) drawBegin: (CGPoint)point {
    _pointCurrent = point;
    
    if (self.ocr.isOCRing) {
        self.ocr.cancelOCR = YES;
    }
    
    self.drawView.image = [[UIImage alloc] init];
    [_selectLabelBounds removeAllObjects];
}

- (NSNumber *)fabs:(NSNumber *)input {
    return [NSNumber numberWithDouble:fabs([input doubleValue])];
}

-(void) drawMove: (CGPoint)point {
    CGPoint pointNext = point;

    UIGraphicsBeginImageContext(self.drawView.frame.size);
    [self.drawView.image drawInRect:CGRectMake(0, 0, self.drawView.frame.size.width, self.drawView.frame.size.height)];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 23.0);
   
    UIColor *brushColor = [UIColor colorWithRed:0.363 green:0.763 blue:1.000 alpha:0.200]; //0.23, 0.67, 0.86, 0.4
    const CGFloat* colors = CGColorGetComponents( brushColor.CGColor );
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), colors[0], colors[1], colors[2], colors[3]);
    
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), _pointCurrent.x, _pointCurrent.y);
    //CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), pointNext.x, pointNext.y);
    CGContextAddQuadCurveToPoint(UIGraphicsGetCurrentContext(), _pointCurrent.x, _pointCurrent.y, pointNext.x, pointNext.y);
    
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
   
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    self.drawView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    _pointCurrent = pointNext;
    
    CGPoint brushT = pointNext;
    brushT.y = brushT.y + 6;
    CGPoint brushB = pointNext;
    brushB.y = brushT.y - 6;
    
 
    [self checkPointInLabelBounds:pointNext];
    [self checkPointInLabelBounds:brushT];
    [self checkPointInLabelBounds:brushB];
 
}

-(void) drawEnd: (CGPoint)point {
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


- (IBAction)onRetake:(id)sender {
    ((UIImagePickerController *)self.picker).delegate = self;
    [self presentViewController:self.picker animated:YES completion:^{
        
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *newImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:NULL];
    _sourceImage = newImage;
    self.isImageOCRed = NO;

    [self ocrImage];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:NULL];
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

-(void) failedOCR: (OCRERRROR)errorCode {
    [self noOCRResult];
    //no drawn bounds
    self.progressView.progress = 0;
}

-(void) startOCR {
    self.progressView.progress = 0;
}
-(void) progressOCR:(NSInteger)progress{
   self.progressView.progress = (float)progress/100;
}


- (void)incrementTyperighterCount
{
    if(_typerRighterCount == 0)
    {
        // Start
    }
    _typerRighterCount++;
}

- (void)decrementTyperighterCount
{
    _typerRighterCount--;
    if(_typerRighterCount <= 0)
    {
        [_ocrResults addObject:_ocrRawResult];
        
        NSString *joinedString = [_ocrResults componentsJoinedByString:@", "];
        NSLog(@"ocr joinedString: %@", joinedString);
        [self showOCRResults];
        // End
        _typerRighterCount = 0;
        self.progressView.progress = 1;
    }
}


-(void) finishOCR:(NSString *)resultString image:(UIImage*)image{

    _ocrResults =[[NSMutableArray alloc] init];
    _ocrRawResult = resultString;
    
    //Collect suggested text from related search of google
    [self incrementTyperighterCount];
    [Typerighter googleTypeRighter:resultString completion:^(NSMutableArray *resultArray, NSError *error) {
        [_ocrResults addObjectsFromArray:resultArray];
        [self decrementTyperighterCount];
        
    }];
    
    //Collect suggested text from related ecTokenization
    [self incrementTyperighterCount];
    [Typerighter ecTokenization:resultString completion:^(NSString *str, NSError *error) {
        if(str!=nil){
            [_ocrResults addObject:str];
        }
        [self decrementTyperighterCount];
    }];
   
}


-(void) ocrDebugImage:(UIImage*)image {
    self.debugImageView.image = image;
}

-(void) cancelledOCR{
    NSLog(@"===========cancelledOCR================");
}

-(void) showOCRResults {
    if(_ocrResults.count>0){
        //self.slideUpView.viewablePixels = MAX(OCRResultViewCellHeight * _ocrResults.count, OCRResultViewCellHeight * (TYPERIGHTER_MAX_NUM+2));
        self.slideUpView.viewablePixels = OCRResultViewCellHeight * _ocrResults.count;
        self.ocrResultView.ocrResults = _ocrResults;
        [self.slideUpView animateIn];
    }else{
        [self noOCRResult];
    }
}

-(void) noOCRResult {
    // TODO: error message

}


#pragma mark - NBSlideUpViewDelegate

- (void)slideUpViewDidAnimateIn:(UIView *)slideUpView {
    NSLog(@"NBSlideUpView animated in.");
}

- (void)slideUpViewDidAnimateOut:(UIView *)slideUpView {
    NSLog(@"NBSlideUpView animated out.");
    [self initDrawingStatus];
    
}

- (void)slideUpViewDidAnimateRestore:(UIView *)slideUpView {
    NSLog(@"NBSlideUpView animated restore.");
}

- (void) didSelectOCRResult:(NSString *)ocrResult {

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
