//
//  CVTools.m
//  ios-snapSearch-live
//
//  Created by Carter Chang on 7/19/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "CVTools.h"




@implementation CVTools




+(std::vector<cv::Rect>) detectLetters:(cv::Mat)img{
    std::vector<cv::Rect> boundRect;
    cv::Mat img_gray, img_sobel, img_threshold, element;
    cvtColor(img, img_gray, CV_BGR2GRAY);
    cv::Sobel(img_gray, img_sobel, CV_8U, 1, 0, 3, 1, 0, cv::BORDER_DEFAULT);
    cv::threshold(img_sobel, img_threshold, 0, 255, CV_THRESH_OTSU+CV_THRESH_BINARY);
    element = getStructuringElement(cv::MORPH_RECT, cv::Size(17, 3) );
    cv::morphologyEx(img_threshold, img_threshold, CV_MOP_CLOSE, element);
    std::vector< std::vector< cv::Point> > contours;
    cv::findContours(img_threshold, contours, 0, 1);
    std::vector<std::vector<cv::Point> > contours_poly( contours.size() );
    for( int i = 0; i < contours.size(); i++ ){
        if (contours[i].size()>100)
        {
            cv::approxPolyDP( cv::Mat(contours[i]), contours_poly[i], 3, true );
            cv::Rect appRect( boundingRect( cv::Mat(contours_poly[i]) ));
            if (appRect.width>appRect.height)
                boundRect.push_back(appRect);
        }
    }
    return boundRect;
}


// Ref: http://docs.opencv.org/doc/tutorials/ios/image_manipulation/image_manipulation.html
+(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

// Ref: http://docs.opencv.org/doc/tutorials/ios/image_manipulation/image_manipulation.html
+ (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}


//-------------
cv::Point2f center(0,0);

cv::Point2f computeIntersect(cv::Vec4i a,
                             cv::Vec4i b)
{
    int x1 = a[0], y1 = a[1], x2 = a[2], y2 = a[3], x3 = b[0], y3 = b[1], x4 = b[2], y4 = b[3];
    float denom;
    
    if (float d = ((float)(x1 - x2) * (y3 - y4)) - ((y1 - y2) * (x3 - x4)))
    {
        cv::Point2f pt;
        pt.x = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / d;
        pt.y = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / d;
        return pt;
    }
    else
        return cv::Point2f(-1, -1);
}

void sortCorners(std::vector<cv::Point2f>& corners,
                 cv::Point2f center)
{
    std::vector<cv::Point2f> top, bot;
    
    for (int i = 0; i < corners.size(); i++)
    {
        if (corners[i].y < center.y)
            top.push_back(corners[i]);
        else
            bot.push_back(corners[i]);
    }
    corners.clear();
    
    if (top.size() == 2 && bot.size() == 2){
        cv::Point2f tl = top[0].x > top[1].x ? top[1] : top[0];
        cv::Point2f tr = top[0].x > top[1].x ? top[0] : top[1];
        cv::Point2f bl = bot[0].x > bot[1].x ? bot[1] : bot[0];
        cv::Point2f br = bot[0].x > bot[1].x ? bot[0] : bot[1];
        
        
        corners.push_back(tl);
        corners.push_back(tr);
        corners.push_back(br);
        corners.push_back(bl);
    }
}


+ (cv::Mat) perspectiveCorrection:(cv::Mat)mat {
    cv::Mat src = mat;
    if (src.empty())
        return mat;
    
    cv::Mat bw;
    cv::cvtColor(src, bw, CV_BGR2GRAY);
    cv::blur(bw, bw, cv::Size(3, 3));
    cv::Canny(bw, bw, 100, 100, 3);
    
    std::vector<cv::Vec4i> lines;
    cv::HoughLinesP(bw, lines, 1, CV_PI/180, 70, 30, 10);
    
    // Expand the lines
    for (int i = 0; i < lines.size(); i++)
    {
        cv::Vec4i v = lines[i];
        lines[i][0] = 0;
        lines[i][1] = ((float)v[1] - v[3]) / (v[0] - v[2]) * -v[0] + v[1];
        lines[i][2] = src.cols;
        lines[i][3] = ((float)v[1] - v[3]) / (v[0] - v[2]) * (src.cols - v[2]) + v[3];
    }
    
    std::vector<cv::Point2f> corners;
    for (int i = 0; i < lines.size(); i++)
    {
        for (int j = i+1; j < lines.size(); j++)
        {
            cv::Point2f pt = computeIntersect(lines[i], lines[j]);
            if (pt.x >= 0 && pt.y >= 0)
                corners.push_back(pt);
        }
    }
    
    std::vector<cv::Point2f> approx;
    cv::approxPolyDP(cv::Mat(corners), approx, cv::arcLength(cv::Mat(corners), true) * 0.02, true);
    
    if (approx.size() != 4)
    {
        std::cout << "The object is not quadrilateral!" << std::endl;
        return mat;
    }
    
    // Get mass center
    for (int i = 0; i < corners.size(); i++)
        center += corners[i];
    center *= (1. / corners.size());
    
    sortCorners(corners, center);
    if (corners.size() == 0){
        std::cout << "The corners were not sorted correctly!" << std::endl;
        return mat;
    }
    cv::Mat dst = src.clone();
    
    // Draw lines
    for (int i = 0; i < lines.size(); i++)
    {
        cv::Vec4i v = lines[i];
        cv::line(dst, cv::Point(v[0], v[1]), cv::Point(v[2], v[3]), CV_RGB(0,255,0));
    }
    
    // Draw corner points
    cv::circle(dst, corners[0], 3, CV_RGB(255,0,0), 2);
    cv::circle(dst, corners[1], 3, CV_RGB(0,255,0), 2);
    cv::circle(dst, corners[2], 3, CV_RGB(0,0,255), 2);
    cv::circle(dst, corners[3], 3, CV_RGB(255,255,255), 2);
    
    // Draw mass center
    cv::circle(dst, center, 3, CV_RGB(255,255,0), 2);
    
    cv::Mat quad = cv::Mat::zeros(300, 220, CV_8UC3);
    
    std::vector<cv::Point2f> quad_pts;
    quad_pts.push_back(cv::Point2f(0, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, quad.rows));
    quad_pts.push_back(cv::Point2f(0, quad.rows));
    
    cv::Mat transmtx = cv::getPerspectiveTransform(corners, quad_pts);
    cv::warpPerspective(src, quad, transmtx, quad.size());
    
    return quad;
    //    cv::imshow("image", dst);
    //    cv::imshow("quadrilateral", quad);
    //    cv::waitKey();
}
//-------------



@end
