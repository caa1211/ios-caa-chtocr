//
//  OCRResultView.h
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/31/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import <UIKit/UIKit.h>
#define OCRResultViewCellHeight 44

@protocol OCRResultViewDelegate <NSObject>
- (void) didSelectOCRResult:(NSString *)ocrResult;
@optional

@end


@interface OCRResultView : UIView

- (instancetype)initWithDelegate:(id<OCRResultViewDelegate>)delegate;
@property (nonatomic, weak) id<OCRResultViewDelegate> delegate;
@property (strong, nonatomic) NSMutableArray *ocrResults;

@end
