//
//  ViewController.m
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/13/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "ViewController.h"
#import <TesseractOCR/TesseractOCR.h>

@interface ViewController () <G8TesseractDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.operationQueue = [[NSOperationQueue alloc] init];
    
    UIImage *image = [UIImage imageNamed:@"testImages/003.png"];
    self.imageView.image = image;
   
    
    [self doOCR:image];
}

- (void) doOCR:(UIImage*)image{
    
    // Mark below for avoiding BSXPCMessage error
    UIImage *bwImage =[image g8_blackAndWhite];
    
    G8RecognitionOperation *operation = [[G8RecognitionOperation alloc]initWithLanguage:@"chi_tra"];
    operation.tesseract.maximumRecognitionTime = 30.0;
   // operation.tesseract.engineMode = G8OCREngineModeTesseractOnly;
    
    operation.delegate = self;
    operation.tesseract.image = bwImage;

    operation.recognitionCompleteBlock = ^(G8Tesseract *tesseract) {
        NSLog(@"operation  done");
        // Fetch the recognized text
        NSString *recognizedText = tesseract.recognizedText;
        NSLog(@"recognizedText= %@", recognizedText);
        [G8Tesseract clearCache];
    };
    
    [self.operationQueue addOperation:operation];
}

- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    NSLog(@"progress: %lu", (unsigned long)tesseract.progress);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
