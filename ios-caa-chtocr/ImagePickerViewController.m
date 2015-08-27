//
//  ImagePickerViewController.m
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/27/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "ImagePickerViewController.h"
#import "OCRViewController.h"
#import "OCGumbo/OCGumbo+Query.h"


@interface ImagePickerViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@end

@implementation ImagePickerViewController


- (IBAction)onCamera:(id)sender {
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:^{
        
    }];
}
- (IBAction)onLibrary:(id)sender {
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:^{
        
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *cardImage = [info objectForKey:UIImagePickerControllerOriginalImage];

    OCRViewController *ocrVC = [[OCRViewController alloc] initWithImage: cardImage];
    [picker dismissViewControllerAnimated:YES completion:NULL];

    [self.navigationController pushViewController:ocrVC animated:YES];
  
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:NULL];
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
