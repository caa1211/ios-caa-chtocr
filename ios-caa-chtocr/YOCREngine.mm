//
//  YOCREngine.m
//  eccs
//
//  Created by Carter Chang on 8/17/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "YOCREngine.h"

@interface YOCREngine () <G8TesseractDelegate>

@property (strong, nonatomic) UIImage *highlightLattersImage;
@property (strong, nonatomic) NSMutableArray *ocrResultArray;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property(strong, nonatomic) dispatch_queue_t cropImageQueue;
@property(strong, nonatomic) G8Tesseract *tesseract;
@end

using namespace cv;

@implementation YOCREngine

-(id) init {
    self = [super init];
    
    if(self){
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.cropImageQueue = dispatch_queue_create("crop_queue", nil);
        
        self.tesseract = [[G8Tesseract alloc] initWithLanguage:@"chi_tra"];
        self.tesseract.maximumRecognitionTime = 8.0;
        self.tesseract.delegate = self;
        //self.tesseract.engineMode = G8OCREngineModeTesseractOnly;
        self.tesseract.charBlacklist = @"撇卹黴犬冉鬥愜乒煒蒿咖乂紂噩絜蚳岍圭遏毗咽囓鬮軹[]駟酉彊【】窐奎瞰姍";
        self.cancelOCR = NO;
        
     //charBlacklist
      //charWhitelist
    }
    
    return self;
}

struct pixel {
    unsigned char r, g, b, a;
};


- (UIColor*) getDominantColor:(UIImage*)image
{
    NSUInteger red = 0;
    NSUInteger green = 0;
    NSUInteger blue = 0;
    
    struct pixel* pixels = (struct pixel*) calloc(1, image.size.width * image.size.height * sizeof(struct pixel));
    if (pixels != nil)
    {
        
        CGContextRef context = CGBitmapContextCreate(
                                                     (void*) pixels,
                                                     image.size.width,
                                                     image.size.height,
                                                     8,
                                                     image.size.width * 4,
                                                     CGImageGetColorSpace(image.CGImage),
                                                     kCGImageAlphaPremultipliedLast
                                                     );
        
        if (context != NULL)
        {
            // Draw the image in the bitmap
            
            CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, image.size.width, image.size.height), image.CGImage);
            
            NSUInteger numberOfPixels = image.size.width * image.size.height;
            for (int i=0; i<numberOfPixels; i++) {
                red += pixels[i].r;
                green += pixels[i].g;
                blue += pixels[i].b;
            }
            
            
            red /= numberOfPixels;
            green /= numberOfPixels;
            blue/= numberOfPixels;
            CGContextRelease(context);
        }
        
        free(pixels);
    }
    return [UIColor colorWithRed:red/255.0f green:green/255.0f blue:blue/255.0f alpha:1.0f];
}


- (NSMutableArray *) getLabelBounds:(UIImage *)image {
    cv::Mat mat = [CVTools cvMatFromUIImage:image];
    std::vector<cv::Rect> bounds = [self detectLetters:mat];
    NSMutableArray * boundsArray = [[NSMutableArray alloc] init];
    if (bounds.size() > 0){
        for(int i=0; i< bounds.size(); i++){
            CGRect rect = CGRectMake(bounds[i].x, bounds[i].y, bounds[i].width, bounds[i].height);
            [boundsArray addObject:NSStringFromCGRect(rect)];
        }
        
        return boundsArray;
    }else {
        return nil;
    }
}


-(UIImage *)changeWhiteColorTransparent: (UIImage *)image
{
    CGImageRef rawImageRef=image.CGImage;
    
    CGFloat colorMasking[6] = {255, 255, 255, 255, 255, 255};
    
    UIGraphicsBeginImageContext(image.size);
    CGImageRef maskedImageRef=CGImageCreateWithMaskingColors(rawImageRef, colorMasking);
    {
        //if in iphone
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0, image.size.height);
        CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1.0, -1.0);
    }
    
    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, image.size.width, image.size.height), maskedImageRef);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    CGImageRelease(maskedImageRef);
    UIGraphicsEndImageContext();
    return result;
}


-(void) ocrWithImage:(UIImage *)image inBounds:(NSMutableArray*)boundsArray{
    [self.delegate startOCR];
    self.isOCRing = YES;
    //self.cancelOCR = NO;
    
    dispatch_async(self.cropImageQueue, ^{
        cv::Mat mat = [CVTools cvMatFromUIImage:image];
        std::vector<cv::Rect> bounds = [self bounsArrayToVectors:boundsArray];
        if (bounds.size() > 0){

            [self extractTextFromCVImage:mat letterBoxes:bounds complete:^(NSString *ocrRawResult, UIImage *image) {
                //background thread
                
                NSCharacterSet *doNotWant = [NSCharacterSet characterSetWithCharactersInString:
                                             @" 己皿邯硯菂唰珈」屾,=-)(*&^%$#@!~}{?></:.;\"\'`ˉ\n"];
                NSString *clearOcrResult = [[ocrRawResult componentsSeparatedByCharactersInSet: doNotWant] componentsJoinedByString: @""];
                
                //NSString *clearOcrResult = ocrRawResult;
                
                NSString *trimmedString = [clearOcrResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                
                NSLog(@"recognizedText= %@", trimmedString);
                
                if (self.cancelOCR == YES){
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self.delegate cancelledOCR];
                    });
                }else{
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self.delegate finishOCR:trimmedString image:image];

                    });
                }
                self.isOCRing = NO;
                self.cancelOCR = NO;
                
            }];
        }else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.delegate failedOCR:OCRERRROR_NOBOUNDS];
            });
            self.isOCRing = NO;
            self.cancelOCR = NO;
        }

    });
    
}

-(std::vector<cv::Rect>) bounsArrayToVectors:(NSMutableArray*)boundsArray{
    std::vector<cv::Rect> boundRects;
    for (NSString * boundString in boundsArray) {
        CGRect rect = CGRectFromString(boundString);
        cv::Rect appRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
        boundRects.push_back(appRect);
    }
    return boundRects;
}


-(void) extractTextFromCVImage:(cv::Mat)mat letterBoxes:(std::vector<cv::Rect>)letterBoxes complete:(void(^)(NSString *result, UIImage *image))complete{
    
    self.cancelOCR = NO;
    
    cv::Mat wmat = [self lettersFromImage:mat letterBoxes:letterBoxes];
    
    // Image processing ===
    //     cv::Mat image_copy;
    //            cvtColor(wmat, image_copy, CV_BGRA2BGR);
    //            wmat = image_copy;
    //
    //
    //            // Invert image
    //            bitwise_not(wmat, image_copy);
    //            wmat = image_copy;
    //
    //
    //    cvtColor(wmat, image_copy, CV_RGBA2GRAY);
    //    wmat = image_copy;
    
    
    UIImage *whiteImage = [CVTools UIImageFromCVMat:wmat];
    
    
    //SyncOCR
    NSString *ocrResult = [self doOCR_sync:whiteImage];
    complete(ocrResult, [CVTools UIImageFromCVMat:wmat]);
    
    
//    //AsyncOCR
//    [self doOCR_async:whiteImage complete:^(NSString *recognizedText) {
//         NSString *ocrResult=recognizedText;
//         complete(ocrResult, [CVTools UIImageFromCVMat:wmat]);
//    }];
    
  
}

-(cv::Mat) lettersFromImage:(cv::Mat)mat letterBoxes:(std::vector<cv::Rect>)letterBoxes {
    return [self lettersFromImage:mat letterBoxes:letterBoxes customColor:nil];
}

-(cv::Mat) lettersFromImage:(cv::Mat)mat letterBoxes:(std::vector<cv::Rect>)letterBoxes customColor:(UIColor*)customColor  {
    
    cv::Mat wmat = mat.clone();
    bool isDrawBorder = NO;
    if (customColor == nil) {
        // Fill in average color in background
        UIColor *dominantColor = [self getDominantColor:[CVTools UIImageFromCVMat:wmat]];
        CGFloat red, green, blue, alpha, colorOffset = 0.1;
        [dominantColor getRed: &red
                        green: &green
                         blue: &blue
                        alpha: &alpha];
        //wmat.setTo(cv::Scalar(138,139,131));
        wmat.setTo(cv::Scalar((red+colorOffset)*255,(green+colorOffset)*255,(blue+colorOffset)*255));
        
    }else {
        CGFloat red, green, blue, alpha;
        [customColor getRed: &red
                      green: &green
                       blue: &blue
                      alpha: &alpha];
        wmat.setTo(cv::Scalar(red*255,green*255,blue*255));
        isDrawBorder = YES;
    }
    
    
    for(int i=0; i< letterBoxes.size(); i++){
        cv::Rect rect = letterBoxes[i];
        cv::Mat croppedRef(mat, rect);
        cv::Mat cropped;
        croppedRef.copyTo(cropped);
        cv::Mat cmat = cropped;
        
        Mat imgPanelRoi(wmat, rect);
        cmat.copyTo(imgPanelRoi);
        
        if (isDrawBorder && cmat.data !=NULL && wmat.data !=NULL && wmat.rows!= 0 && rect.width != 0) {
            cv::rectangle(wmat,rect,cv::Scalar(250,250,250),2,16,0);
        }
    }
    return wmat;
    
}


- (NSString *) doOCR_sync:(UIImage*)image{
    
    // Mark below for avoiding BSXPCMessage error
    UIImage *bwImage = [image g8_blackAndWhite];
    
    
    self.tesseract.image =  bwImage;
    
    //self.tesseract.rect = CGRectMake(20, 20, 100, 100);
    
    [self.tesseract recognize];
    
    //    NSArray *characterBoxes = [tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelSymbol];
    //    NSArray *paragraphs = [tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelParagraph];
    //    NSArray *characterChoices = tesseract.characterChoices;
    //    UIImage *imageWithBlocks = [tesseract imageWithBlocks:characterBoxes drawText:YES thresholded:NO];
    
    NSString *recognizedText = self.tesseract.recognizedText;
    
    [self.ocrResultArray addObject:recognizedText];
    [G8Tesseract clearCache];
    return recognizedText;
}

- (void) doOCR_async:(UIImage*)image complete:(void(^)(NSString *recognizedText))complete{
    
    // Mark below for avoiding BSXPCMessage error
    UIImage *bwImage = [image g8_blackAndWhite];
    
    G8RecognitionOperation *operation = [[G8RecognitionOperation alloc]initWithLanguage:@"chi_tra"];
    operation.tesseract.maximumRecognitionTime = 8.0;
    operation.delegate = self;
    operation.tesseract.image = bwImage;
    
    operation.recognitionCompleteBlock = ^(G8Tesseract *tesseract) {
        NSString *recognizedText = self.tesseract.recognizedText;
        [self.ocrResultArray addObject:recognizedText];
        complete(recognizedText);
        [G8Tesseract clearCache];
    };
    
    [self.operationQueue addOperation:operation];
}

- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    dispatch_sync(dispatch_get_main_queue(), ^{
        //NSLog(@"progress: %lu", (unsigned long)tesseract.progress);
        [self.delegate progressOCR:tesseract.progress];
    });
}

- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    return self.cancelOCR;
}

-(std::vector<cv::Rect>) detectLettersFromUIImage:(UIImage*)image {
    cv::Mat mat = [CVTools cvMatFromUIImage:image];
    return [self detectLetters:mat];
}


-(std::vector<cv::Rect>) detectLetters:(cv::Mat)img{
    std::vector<cv::Rect> boundRect;
    cv::Mat img_gray, img_sobel, img_threshold, element;
    cvtColor(img, img_gray, CV_BGR2GRAY);
    cv::Sobel(img_gray, img_sobel, CV_8U, 1, 0, 3, 1, 0, cv::BORDER_DEFAULT);

    cv::threshold(img_sobel, img_threshold, 0, 255, CV_THRESH_OTSU+CV_THRESH_BINARY);
    
    element = getStructuringElement(cv::MORPH_RECT, cv::Size(17, 5) );
    cv::morphologyEx(img_threshold, img_threshold, CV_MOP_CLOSE, element);
    
    //[self.delegate ocrDebugImage:[CVTools UIImageFromCVMat:img_threshold]];
    
    std::vector< std::vector< cv::Point> > contours;
    cv::findContours(img_threshold, contours, 0, 1);
    std::vector<std::vector<cv::Point> > contours_poly( contours.size() );

    for( int i = 0; i < contours.size(); i++ ){
     
        if (contours[i].size() > 80)
        {
            //NSLog(@"=========contours[i].size() %d==================", contours[i].size());
          
            cv::approxPolyDP( cv::Mat(contours[i]), contours_poly[i], 3, true );
            cv::Rect appRect( boundingRect( cv::Mat(contours_poly[i]) ));
            
            
            if ( (float)appRect.width / appRect.height > 1.5 &&
                appRect.height > 20){
                boundRect.push_back(appRect);
            }

        }
    }
    //NSLog(@"contours[i].size() > 400,  %ld", count);
    return boundRect;
}

-(UIImage *) perspectiveTransform:(UIImage*)image{
    cv::Mat src_img = [CVTools cvMatFromUIImage:image];
    int nOffset=-100;
    cv::Point2f pts1[] = {cv::Point2f(0,0),cv::Point2f(0,src_img.rows),cv::Point2f(src_img.cols,src_img.rows),cv::Point2f(src_img.cols,0)};
    cv::Point2f pts2[] = {cv::Point2f(0,0),cv::Point2f(0+nOffset,src_img.rows),cv::Point2f(src_img.cols-nOffset,src_img.rows),cv::Point2f(src_img.cols,0)};
    cv::Mat perspective_matrix = cv::getPerspectiveTransform(pts1, pts2);
    cv::Mat dst_img;
    
    cv::warpPerspective(src_img, dst_img, perspective_matrix, src_img.size(), cv::INTER_LINEAR);
    
    cv::line(src_img, pts1[0], pts1[1], cv::Scalar(255,255,0), 2, CV_AA);
    cv::line(src_img, pts1[1], pts1[2], cv::Scalar(255,255,0), 2, CV_AA);
    cv::line(src_img, pts1[2], pts1[3], cv::Scalar(255,255,0), 2, CV_AA);
    cv::line(src_img, pts1[3], pts1[0], cv::Scalar(255,255,0), 2, CV_AA);
    cv::line(src_img, pts2[0], pts2[1], cv::Scalar(255,0,255), 2, CV_AA);
    cv::line(src_img, pts2[1], pts2[2], cv::Scalar(255,0,255), 2, CV_AA);
    cv::line(src_img, pts2[2], pts2[3], cv::Scalar(255,0,255), 2, CV_AA);
    cv::line(src_img, pts2[3], pts2[0], cv::Scalar(255,0,255), 2, CV_AA);
    
    return [CVTools UIImageFromCVMat:dst_img];
}

@end
