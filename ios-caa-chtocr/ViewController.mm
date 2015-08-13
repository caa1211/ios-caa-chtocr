//
//  ViewController.m
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/13/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "ViewController.h"
#import <TesseractOCR/TesseractOCR.h>
#import <opencv2/videoio/cap_ios.h>
#import "CVTools.h"

using namespace cv;

@interface ViewController () <G8TesseractDelegate>
@property (weak, nonatomic) IBOutlet UISegmentedControl *imageSelector;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property(strong, nonatomic) dispatch_queue_t cropImageQueue;
@property(assign, nonatomic) bool cancelOCR;
@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.imageSelector addTarget:self action:@selector(onSampleChange:) forControlEvents:UIControlEventValueChanged];
    
    // Do any additional setup after loading the view, typically from a nib.
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.cropImageQueue = dispatch_queue_create("crop_queue", nil);
    
    // Text View
    self.textView.editable = NO;
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineHeightMultiple = 12.0f;
    paragraphStyle.maximumLineHeight = 12.0f;
    paragraphStyle.minimumLineHeight = 12.0f;
    NSDictionary *ats = @{
                          NSParagraphStyleAttributeName : paragraphStyle,
                          };
    self.textView.attributedText = [[NSAttributedString alloc] initWithString:@" " attributes:ats];
    
    // Default target image
    [self extractTextFromImage:[UIImage imageNamed:@"testImages/003-1.png"]];
    
    self.cancelOCR = NO;
}

-(void) extractTextFromImage:(UIImage*)image {
    // Draw green text area
    UIImage *lettersAreaImage = [self drawLettersArea:image];
    self.imageView.image = lettersAreaImage;
    self.textView.text = @"";
    dispatch_async(self.cropImageQueue, ^{
        // Crop image
        NSMutableArray *imgAry = [self cropLetters:image];
        NSLog(@"===========%ld================", imgAry.count);
        self.cancelOCR = NO;
        for (UIImage *cropedImage in imgAry) {
            //[self doOCR_sync:cropedImage];
            [self doOCR_async:cropedImage];
        }
    });
}


- (void) onSampleChange:(id) sender {
    UIImage *image = nil;
    self.cancelOCR = YES;
    switch (self.imageSelector.selectedSegmentIndex) {
        case 0:
            image = [UIImage imageNamed:@"testImages/001.png"];
            break;
        case 1:
            image = [UIImage imageNamed:@"testImages/002.png"];
            break;
        case 2:
            image = [UIImage imageNamed:@"testImages/003.png"];
            break;
        case 3:
            image = [UIImage imageNamed:@"testImages/004.png"];
            break;
        case 4:
            image = [UIImage imageNamed:@"testImages/005.png"];
            break;
        case 5:
            image = [UIImage imageNamed:@"testImages/006.png"];
            break;
        case 6:
            image = [UIImage imageNamed:@"testImages/007.png"];
            break;
        default:
            image = [UIImage imageNamed:@"testImages/003.png"];
            break;
    }

    [self extractTextFromImage:image];
    
}

- (UIImage *) drawLettersArea:(UIImage *)image {
    UIImage *resImg;
    cv::Mat mat = [CVTools cvMatFromUIImage:image];
    
    std::vector<cv::Rect> letterBBoxes= [self detectLetters:mat];
    for(int i=0; i< letterBBoxes.size(); i++){
        cv::rectangle(mat,letterBBoxes[i],cv::Scalar(0,255,0),3,8,0);
    }
    resImg = [CVTools UIImageFromCVMat:mat];
    return resImg;
}

- (NSMutableArray *) cropLetters:(UIImage *)image {
    NSMutableArray* imgAry = [[NSMutableArray alloc]init];
    cv::Mat mat = [CVTools cvMatFromUIImage:image].clone();
    std::vector<cv::Rect> letterBBoxes= [self detectLetters:mat];
    
    
    cv::Mat image_copy;
    cvtColor(mat, image_copy, CV_BGRA2BGR);
    mat = image_copy;

//    bitwise_not(mat, image_copy);
//    mat = image_copy;
    
//    cvtColor(mat, image_copy, CV_RGBA2GRAY);
//    mat = image_copy;
    
    for(int i=0; i< letterBBoxes.size(); i++){
        UIImage *cropedImg;
        cv::Rect rect = letterBBoxes[i];
        cv::Mat croppedRef(mat, rect);
        cv::Mat cropped;
        croppedRef.copyTo(cropped);
        cv::Mat cmat = cropped;
        cropedImg = [CVTools UIImageFromCVMat:cmat];
        [imgAry addObject:cropedImg];
    }
    return imgAry;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - OCR

- (void) doOCR_sync:(UIImage*)image{
    
    // Mark below for avoiding BSXPCMessage error
    UIImage *bwImage = image;//[image g8_blackAndWhite];
    
    G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"chi_tra"];
    tesseract.delegate = self;
    tesseract.image = image;
    //tesseract.rect = CGRectMake(20, 20, 100, 100);
    
    [tesseract recognize];
    
    NSArray *characterBoxes = [tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelSymbol];
    NSArray *paragraphs = [tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelParagraph];
    NSArray *characterChoices = tesseract.characterChoices;
    UIImage *imageWithBlocks = [tesseract imageWithBlocks:characterBoxes drawText:YES thresholded:NO];
    
    NSString *recognizedText = tesseract.recognizedText;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.textView replaceRange:self.textView.selectedTextRange withText:recognizedText];
    });
}

- (void) doOCR_async:(UIImage*)image{
    
    // Mark below for avoiding BSXPCMessage error
    UIImage *bwImage = image;//[image g8_blackAndWhite];
    
    G8RecognitionOperation *operation = [[G8RecognitionOperation alloc]initWithLanguage:@"chi_tra"];
    operation.tesseract.maximumRecognitionTime = 3.0;
    // operation.tesseract.engineMode = G8OCREngineModeTesseractOnly;
    
    operation.delegate = self;
    operation.tesseract.image = bwImage;
    
    operation.recognitionCompleteBlock = ^(G8Tesseract *tesseract) {
        NSLog(@"operation  done");
        // Fetch the recognized text
        NSString *recognizedText = tesseract.recognizedText;
        NSLog(@"recognizedText= %@", recognizedText);
        
        
        [self.textView replaceRange:self.textView.selectedTextRange withText:recognizedText];

        [G8Tesseract clearCache];
    };
    
    [self.operationQueue addOperation:operation];
}

- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    NSLog(@"progress: %lu", (unsigned long)tesseract.progress);
}

- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    return self.cancelOCR;
}

#pragma mark - openCV

//-(std::vector<cv::Rect>) detectLetters:(cv::Mat)img{
//    std::vector<cv::Rect> boundRect;
//    cv::Mat img_gray, img_sobel, img_threshold, element;
//    cvtColor(img, img_gray, CV_BGR2GRAY);
//    cv::Sobel(img_gray, img_sobel, CV_8U, 1, 0, 3, 1, 0, cv::BORDER_DEFAULT);
//    cv::threshold(img_sobel, img_threshold, 0, 255, CV_THRESH_OTSU+CV_THRESH_BINARY);
//    element = getStructuringElement(cv::MORPH_RECT, cv::Size(17, 3) );
//    cv::morphologyEx(img_threshold, img_threshold, CV_MOP_CLOSE, element);
//    std::vector< std::vector< cv::Point> > contours;
//    cv::findContours(img_threshold, contours, 0, 1);
//    std::vector<std::vector<cv::Point> > contours_poly( contours.size() );
//    for( int i = 0; i < contours.size(); i++ ){
//        if (contours[i].size()>100)
//        {
//            cv::approxPolyDP( cv::Mat(contours[i]), contours_poly[i], 3, true );
//            cv::Rect appRect( boundingRect( cv::Mat(contours_poly[i]) ));
//            if (appRect.width>appRect.height)
//                boundRect.push_back(appRect);
//        }
//    }
//    return boundRect;
//}

-(std::vector<cv::Rect>) detectLetters:(cv::Mat)img{
    std::vector<cv::Rect> boundRect;
    cv::Mat img_gray, img_sobel, img_threshold, element;
    cvtColor(img, img_gray, CV_BGR2GRAY);
    cv::Sobel(img_gray, img_sobel, CV_8U, 1, 0, 3, 1, 0, cv::BORDER_DEFAULT);
    cv::threshold(img_sobel, img_threshold, 0, 255, CV_THRESH_OTSU+CV_THRESH_BINARY);
    element = getStructuringElement(cv::MORPH_RECT, cv::Size(23, 2) );
    cv::morphologyEx(img_threshold, img_threshold, CV_MOP_CLOSE, element);
    std::vector< std::vector< cv::Point> > contours;
    cv::findContours(img_threshold, contours, 0, 1);
    std::vector<std::vector<cv::Point> > contours_poly( contours.size() );
    for( int i = 0; i < contours.size(); i++ ){
        if (contours[i].size()>600)
        {
            cv::approxPolyDP( cv::Mat(contours[i]), contours_poly[i], 3, true );
            cv::Rect appRect( boundingRect( cv::Mat(contours_poly[i]) ));
            if (appRect.width>appRect.height)
                boundRect.push_back(appRect);
        }
    }
    return boundRect;
}

@end
