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


@interface OCRViewController () <YOCREngineDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UIImageViewAligned *ocrImageView;
@property (strong, nonatomic) YOCREngine *ocr;
@property (weak, nonatomic) IBOutlet UIImageView *drawView;
@property (assign, nonatomic) CGPoint pointCurrent;
@property (strong, nonatomic) NSMutableArray *labelBoundsArray_image;
@property (strong, nonatomic) NSMutableArray *labelBoundsArray_screen;
@property (strong, nonatomic) NSMutableArray *selectLabelBounds;
@property (strong, nonatomic) UIImage* sourceImage;
@property (weak, nonatomic) IBOutlet UITextView *debugLabel;
@property (weak, nonatomic) IBOutlet UIView *ocrWrapperView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (assign, nonatomic) BOOL isImageOCRed;
@property (assign, nonatomic) NSInteger typerRighterCount;
@property (strong, nonatomic) NSMutableArray *ocrResults; //Collected from related search
@property (strong, nonatomic) NSString *ocrRawResult; // OCR raw result
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
    
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    if (self.isImageOCRed != YES) {
        [self ocrImage];
        self.isImageOCRed = YES;
    }
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _sourceImage = nil;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

}

-(void) ocrImage {

    _typerRighterCount = 0;
    _labelBoundsArray_image = [[NSMutableArray alloc] init];
    _labelBoundsArray_screen = [[NSMutableArray alloc] init];
    _selectLabelBounds = [[NSMutableArray alloc] init];

    if (self.ocr.isOCRing) {
        self.ocr.cancelOCR = YES;
    }
    
    self.drawView.image = [[UIImage alloc] init];
    self.progressView.progress = 0;
    self.debugLabel.text = @"";
    
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
        rectangleFill.backgroundColor = [UIColor whiteColor];
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

-(void) drawMove: (CGPoint)point {
    CGPoint pointNext = point;

    UIGraphicsBeginImageContext(self.drawView.frame.size);
    [self.drawView.image drawInRect:CGRectMake(0, 0, self.drawView.frame.size.width, self.drawView.frame.size.height)];
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 20.0);
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), 0.23, 0.67, 0.86, 0.7);
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

-(void) startOCR {
    self.progressView.progress = 0;
    self.debugLabel.text = @"";
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
        self.debugLabel.text = joinedString;
        NSLog(@"ocr joinedString: %@", joinedString);
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

-(void) failedOCR: (OCRERRROR)errorCode {
    self.debugLabel.text = @"[no drawn bounds]";
    self.progressView.progress = 0;
}


-(void) cancelledOCR{
    NSLog(@"===========cancelledOCR================");
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
