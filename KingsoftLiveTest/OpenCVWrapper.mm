//
//  OpenCVWrapper.m
//  KingsoftLiveTest
//
//  Created by Khang L on 18/10/2022.
//

#ifdef __cplusplus
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"

#import <opencv2/opencv.hpp>
#import "OpenCVWrapper.h"

#import <CoreVideo/CVPixelBuffer.h>
#include <iostream>
#include "FaceDetect.h"
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgcodecs/ios.h>
#import <GPUImage/GPUImagePicture.h>
#import "GPUImageFaceWidgetComposeFilter.h"
#pragma clang pop
#endif

using namespace std;
@interface OpenCVWrapper ()

@property BOOL isFrontCamera;
@property FaceDetect *facDetector; // AI detect face
@end

@implementation OpenCVWrapper

-(void)configure {
    self.isFrontCamera = YES;
    self.facDetector = [[FaceDetect alloc] init :false];
}

+ (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

//- (cv::Mat) matFromImageBuffer: (CVImageBufferRef) buffer {
//
//    cv::Mat mat ;
//
//    CVPixelBufferLockBaseAddress(buffer, 0);
//
//    void *address = CVPixelBufferGetBaseAddress(buffer);
//    int width = (int) CVPixelBufferGetWidth(buffer);
//    int height = (int) CVPixelBufferGetHeight(buffer);
//
//    mat   = cv::Mat(height, width, CV_8UC4, address, 0);
//    //cv::cvtColor(mat, _mat, CV_BGRA2BGR);
//
//    CVPixelBufferUnlockBaseAddress(buffer, 0);
//
//    return mat;
//}

- (NSArray *)grepFacesForPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    // b1: tao ra anh cv::Mat
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    void* bufferAddress;
    size_t width;
    size_t height;
    size_t bytesPerRow;
    int format_opencv;
    format_opencv = CV_8UC4;

    bufferAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    width = CVPixelBufferGetWidth(pixelBuffer);
    height = CVPixelBufferGetHeight(pixelBuffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow); // anh cv::Mat
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );

    // b2: resize va chuyen sang gray image
    float scale = 0.35;
    if(self.isFrontCamera){
        scale = 0.3;
    }

    cv::resize(image(cv::Rect(0,160,720,960)),image,cv::Size(scale*image.cols,scale*image.cols * 1.33),0 ,0 ,cv::INTER_NEAREST);
    __block cv::Mat_<uint8_t> gray_image;
    cv::cvtColor(image, gray_image, CV_BGR2GRAY); // chuyen sang gray image, de tang toc phan tich

    // call opencv phan tich mat
    NSArray *faces = [self.facDetector landmark:gray_image scale:scale lowModel:false isFrontCamera:self.isFrontCamera];
    gray_image.release();
    // su dung faces data sau khi tich hop
    NSLog(@"Count %lu", (unsigned long)faces.count);
    return faces;
}

- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    // b1: tao ra anh cv::Mat
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress( imageBuffer, 0 );
    void* bufferAddress;
    size_t width;
    size_t height;
    size_t bytesPerRow;
    int format_opencv;
    format_opencv = CV_8UC4;
 
    bufferAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    width = CVPixelBufferGetWidth(imageBuffer);
    height = CVPixelBufferGetHeight(imageBuffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow); // anh cv::Mat
    CVPixelBufferUnlockBaseAddress( imageBuffer, 0 );
    
    // b2: resize va chuyen sang gray image
    float scale = 0.35;
    if(self.isFrontCamera){
        scale = 0.3;
    }
    
    cv::resize(image(cv::Rect(0,160,720,960)),image,cv::Size(scale*image.cols,scale*image.cols * 1.33),0 ,0 ,cv::INTER_NEAREST);
    __block cv::Mat_<uint8_t> gray_image;
    cv::cvtColor(image, gray_image, CV_BGR2GRAY); // chuyen sang gray image, de tang toc phan tich
 
    // call opencv phan tich mat
    NSArray *faces = [self.facDetector landmark:gray_image scale:scale lowModel:false isFrontCamera:self.isFrontCamera];
    gray_image.release();
    // su dung faces data sau khi tich hop
    NSLog(@"Count %lu", (unsigned long)faces.count);
    
}

@end
