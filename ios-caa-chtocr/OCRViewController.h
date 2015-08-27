//
//  OCRViewController.h
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/27/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OCRViewController : UIViewController
- (id)initWithImage:(UIImage *)image;
@property(strong, nonatomic) UIViewController *picker;
@end
