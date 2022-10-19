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
#import "Category.h"
#pragma clang pop
#endif

using namespace std;
@interface OpenCVWrapper ()

@property BOOL isFrontCamera;
@property FaceDetect *facDetector; // AI detect face
@end

typedef enum{
    EyeCenter,
    LeftEyeCenter,
    RightEyeCenter,
    MouthMidPoint,
    MouthLeft,
    MouthRight,
    NoseBottom,
    MouthTop,
    MouthBottom,
}Position;

@interface OpenCVWrapper ()

@property BOOL mouthOpening;
@property CGFloat xcrop;
@property CGFloat xoffect;
@property BOOL detectoredFace;
@property NSTimeInterval lastDetectorFaceTime;



@end

@implementation OpenCVWrapper

-(void)configure {
    self.isFrontCamera = YES;
    self.facDetector = [[FaceDetect alloc] init :false];
}

+ (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

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
    [self GPUVCWillOutputFeatures:faces];
}

- (void)GPUVCWillOutputFeatures:(NSArray *)faceArray
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    // MARK: - reset if no face
    if (!faceArray || [faceArray count]<1) {
//        // reset toan bo sticker params cua 6 filter item
//        NSDictionary *parames = @{ @"count" : @"0"};
//        [self.faceWidgetFilter setStickerParams:parames];
//        [self.faceWidgetFilter1 setStickerParams:parames];
//        [self.faceWidgetFilter2 setStickerParams:parames];
//        [self.faceWidgetFilter3 setStickerParams:parames];
//        [self.faceWidgetFilter4 setStickerParams:parames];
//        [self.faceWidgetFilter5 setStickerParams:parames];
//        [self.meshFilter setItems:nil];
//        self.backgroundFilter.fcount = 0;
        self.detectoredFace = NO;
//        if((now - self.lastDetectorFaceTime) > 0.5){ //  neu tren 0.5s tinh tu lan cuoi phat hien ra face thi hien alert view (uiimageview)
//            dispatch_async(dispatch_get_main_queue(), ^{
//                self.faceAlertView.hidden = NO;
//                NSLog(@"");
//            });
//        }
//        self.faceFilter.items = nil;
        self.mouthOpening = NO;
//        self.mouthStickerFrameIndex = 0;
        return; // exit
    }

    self.lastDetectorFaceTime = now;
    
    self.detectoredFace = YES;
 
    NSMutableDictionary *ftemplate = [[NSMutableDictionary alloc] init];
    [ftemplate setObject:@"0" forKey:@"count"];
    [ftemplate setObject:[NSMutableArray new]  forKey:@"angle"];
    [ftemplate setObject:[NSMutableArray new] forKey:@"point"];
    [ftemplate setObject:[NSMutableArray new] forKey:@"size"];
    
    NSMutableArray *faceParameArray = [[NSMutableArray alloc] initWithObjects:[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy], nil];
    
    NSInteger currentFeature = 0;
    NSInteger faceCount = [faceArray count];
 
    // xu ly data
    for(NSDictionary *faceInArr in faceArray){
        NSMutableArray *item = [NSMutableArray new];
        CGRect faceRect = CGRectFromString(faceInArr[@"rect"]);
        faceRect.size.width = faceRect.size.width * 0.62;
        faceRect.size.height = faceRect.size.width * 0.62;
        
        NSInteger face[136];
        for (int i =0; i < 136; i++) {
            if(i < 120){
                face[i] = [[faceInArr[@"shape"] objectAtIndex:i] integerValue];
            }else if(i == 120 || i == 121 || i == 128 ||  i == 129){
                face[i] = 0;
                continue;
            }else if (i > 129 ){
                face[i] = [[faceInArr[@"shape"] objectAtIndex:(i-4)] integerValue];
            }else if (i > 121 ){
                face[i] = [[faceInArr[@"shape"] objectAtIndex:(i-2)] integerValue];
            }
            if(i % 2 != 0){
                face[i] +=(160 - self.xoffect);
            }
        }
        int i=0;
 
        CGPoint p27 = CGPointMake(face[27*2], face[27*2+1]);
        CGPoint p30 = CGPointMake(face[30*2], face[30*2+1]);
        CGPoint p33 = CGPointMake(face[33*2], face[33*2+1]);
        CGPoint leftEayCenter = [self midPointWithIndex:36 :39 :face];
        CGPoint rightEayCenter = [self midPointWithIndex:42 :45 :face];
        CGPoint mouthMidPoint = [self midPointWithIndex:51 :57 :face];
        CGPoint mouthLeft = CGPointMake(face[48*2], face[48*2+1]);
        CGPoint mouthRight =CGPointMake(face[54*2], face[54*2+1]);
        CGPoint noseBottom =CGPointMake(face[30*2], face[30*2+1]);
        CGPoint mouthTop = CGPointMake(face[51*2], face[51*2+1]);
        CGPoint mouthBottom = CGPointMake(face[57*2], face[57*2+1]);
        CGPoint eayCenter = p27;
        
        CGFloat b = rightEayCenter.y - leftEayCenter.y;
        CGFloat a = rightEayCenter.x - leftEayCenter.x;
        CGFloat c = sqrtf(a * a + b * b);
        CGPoint angle;
        
        angle = CGPointMake((b/c),a/c);
        float sin = angle.x;
        float cos = angle.y;
        float rad = asin(sin);
 
        NSInteger faceW;
        faceW = faceRect.size.width;
 
        CGFloat mouthW = [self distance:mouthLeft :mouthRight];
        CGFloat noseH = [self distance:p27 :p30];
        
        CGPoint t = [self rotation:CGPointMake(mouthLeft.x + mouthW*0.08, mouthLeft.y) :mouthLeft :sin :cos];
        face[120] = t.x;
        face[121] = t.y;
        t = [self rotation:CGPointMake(mouthRight.x - mouthW*0.08, mouthRight.y) :mouthRight :sin :cos];
        face[128] = t.x;
        face[129] = t.y;
 
        CGPoint p62 = CGPointMake(face[62*2], face[62*2+1]);
        CGPoint p66 = CGPointMake(face[66*2], face[66*2+1]);
        if([self distance:p62 :p66]/mouthW > 0.3 && !self.mouthOpening){
            self.mouthOpening = YES;
        }
        
        //膨胀外轮廓
        i = 0;
        float length = faceW * 0.02;
        for(int i= 0; i < 34;i += 2){
            CGPoint pot = CGPointMake(face[i], face[i+1]);
            float distance = [self distance:pot :p33];
            face[i] = pot.x + (pot.x - p33.x) / distance * length;
            face[i+1] = pot.y + (pot.y - p33.y) / distance * length;
        }
        
        //外轮廓
        for (int i = 0; i < 32; i+=2) {
            int j = i / 2;
            CGPoint pot = CGPointMake(face[j*2], face[j*2+1]);
            CGPoint npot = CGPointMake(face[j*2+2], face[j*2+3]);
            item[i] = [NSValue valueWithCGPoint:CGPointMake(pot.x, pot.y)];
            item[i+1] = [NSValue valueWithCGPoint:[self midPoint:pot :npot]];
        }

        item[32] = [NSValue valueWithCGPoint:CGPointMake(face[32], face[33])];
        //中心部位
        for (int i = 17; i < 64; i++) {
            int j = i + 16;
            item[j] = [NSValue valueWithCGPoint:CGPointMake(face[i*2], face[i*2+1])];
        }
        //眉毛下
        NSInteger offset = (int)(noseH * 0.10);
        for (int i = 0; i < 4; i++) {
            int j = i + 18;
            CGPoint m = CGPointMake(face[j*2], face[j*2+1]);
            NSInteger useOffset = offset;
            if(i == 3){
                useOffset = offset / 1.3;
            }
            item[64+i] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(m.x, m.y + useOffset) :m :sin :cos]];
        }
        for (int i = 0; i < 4; i++) {
            int j = i + 22;
            CGPoint m = CGPointMake(face[j*2], face[j*2+1]);
            NSInteger useOffset = offset;
            if(i == 3){
                useOffset = offset / 1.3;
            }
            item[68+i] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(m.x, m.y + useOffset) :m :sin :cos]];
        }
        
        //左眼中心
        item[72] = [NSValue valueWithCGPoint:[self midPointWithIndex:37 :38 :face]];
        item[73] = [NSValue valueWithCGPoint:[self midPointWithIndex:40 :41 :face]];
        item[74] = [NSValue valueWithCGPoint:[self midPointWithIndex:36 :39 :face]];
        item[75] = [NSValue valueWithCGPoint:[self midPointWithIndex:43 :44 :face]];
        item[76] = [NSValue valueWithCGPoint:[self midPointWithIndex:47 :46 :face]];
        item[77] = [NSValue valueWithCGPoint:[self midPointWithIndex:42 :45 :face]];
        
        //鼻子上部左右
        item[78] = [NSValue valueWithCGPoint:[self midPointWithIndex:39 :27 :face]];
        item[79] = [NSValue valueWithCGPoint:[self midPointWithIndex:42 :27 :face]];
        CGPoint p29 = CGPointMake(face[29*2], face[29*2+1]);
        CGPoint p31 = CGPointMake(face[31*2], face[31*2+1]);
        CGPoint p35 = CGPointMake(face[35*2], face[35*2+1]);

        item[80] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p29.x - noseH/6., p29.y + noseH/12.) :p29 :sin :cos]];
        item[81] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p29.x + noseH/6, p29.y + noseH/12.) :p29 :sin :cos]];
        item[82] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p31.x - noseH /16., p31.y - noseH / 16.) :p31 :sin :cos]];
        item[83] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p35.x + noseH /16., p35.y - noseH / 16.) :p35 :sin :cos]];
        
        for (int i = 0; i < 20; i++) {
            int j = i + 48;
            item[84+i] = [NSValue valueWithCGPoint:CGPointMake(face[j*2], face[j*2+1])];
        }
        
        //眼睛下侧两点
        item[104] = [NSValue valueWithCGPoint:[self midPointWithIndex:38 :41 :face]];
        item[105] = [NSValue valueWithCGPoint:[self midPointWithIndex:44 :47 :face]];
        //脸颊两侧
        CGPoint p2 = CGPointMake(face[2*2], face[2*2+1]);
        CGPoint p14 = CGPointMake(face[14*2], face[14*2+1]);
        CGPoint pot = CGPointMake(p31.x - [self distance:p31 :p2] / 1.5, p31.y);
        item[106] = [NSValue valueWithCGPoint:[self rotation:pot :p31 :sin :cos]];
        pot = CGPointMake(p35.x + [self distance:p35 :p14] / 1.5, p35.y);
        item[107] = [NSValue valueWithCGPoint:[self rotation:pot :p35 :sin :cos]];
        //额头
        CGPoint p17 = CGPointMake(face[17*2], face[17*2+1]);
        CGPoint p19 = CGPointMake(face[19*2], face[19*2+1]);
        CGPoint p20 = CGPointMake(face[20*2], face[20*2+1]);
        CGPoint p23 = CGPointMake(face[23*2], face[23*2+1]);
        CGPoint p24 = CGPointMake(face[24*2], face[24*2+1]);

        CGPoint p26 = CGPointMake(face[26*2], face[26*2+1]);
        CGPoint p39 = CGPointMake(face[39*2], face[39*2+1]);
        CGPoint p42 = CGPointMake(face[42*2], face[42*2+1]);
        
        CGPoint p110 = [self midPoint:p39 :p42];
        p110.y -= faceW * 0.8;
 
        item[108] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p17.x , p110.y) :p27 :sin :cos]];
        item[109] = [NSValue valueWithCGPoint:[self rotation:CGPointMake((p19.x + p20.x) / 2., p110.y) :p27 :sin :cos]];
        item[110] = [NSValue valueWithCGPoint:[self rotation:p110 :p27 :sin :cos]];
        item[111] = [NSValue valueWithCGPoint:[self rotation:CGPointMake((p23.x + p24.x) / 2., p110.y) :p27 :sin :cos]];
        item[112] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p26.x, p110.y) :p27 :sin :cos]];

        i = 0;
        if([self isEmpty:self.stickerConfig[@"items"]]){
            continue;
        }
        
        for (NSDictionary *item in self.stickerConfig[@"items"]) {
            if([item[@"position"] intValue] >= 10){
                continue;
            }
            NSMutableDictionary *faceParames = [faceParameArray objectAtIndex:i];
            faceParames[@"count"] = @(faceCount);
            CGSize stickSize = CGSizeMake([item[@"width"] floatValue],[item[@"height"] floatValue]);
            int position = [item[@"position"] intValue];
            UIEdgeInsets insert = UIEdgeInsetsFromString(item[@"insert"]);
            CGPoint sizePoint;
            CGPoint center = CGPointMake(face[30*2], face[30*2+1]);
            
            CGFloat w = faceRect.size.width * [item[@"scale"] floatValue];
            sizePoint = CGPointMake(w / self.cameraSize.width, w * (stickSize.height/stickSize.width)/self.cameraSize.height);
            [faceParames[@"size"] addObject:NSStringFromCGPoint(sizePoint)];
            [faceParames[@"angle"] addObject:NSStringFromCGPoint(angle)];
            
            switch (position) {
                case EyeCenter:
                    center = eayCenter;
                    break;
                case LeftEyeCenter:
                    center = leftEayCenter;
                    break;
                case RightEyeCenter:
                    center = rightEayCenter;
                    break;
                case MouthMidPoint:
                    center = mouthMidPoint;
                    break;
                case MouthLeft:
                    center = mouthLeft;
                    break;
                case MouthRight:
                    center = mouthRight;
                    break;
                case NoseBottom:
                    center = noseBottom;
                    break;
                case MouthTop:
                    center = mouthTop;
                    break;
                case MouthBottom:
                    center = mouthBottom;
                    break;
                default:
                    break;
            }
            
            CGPoint offsetSize = CGPointMake((insert.left - insert.right) * sizePoint.x, (insert.top - insert.bottom) * sizePoint.y);
            CGPoint firstCenter = CGPointMake(center.x / self.cameraSize.width, center.y / self.cameraSize.height);
            
            CGPoint finalCenter = CGPointMake(0.5, 0.5);
            finalCenter.x = firstCenter.x + (cos * offsetSize.x - sin * offsetSize.y) * (self.cameraSize.height / self.cameraSize.width);
            finalCenter.y = firstCenter.y + (sin * offsetSize.x + cos * offsetSize.y);
            [faceParames[@"point"] addObject:NSStringFromCGPoint(finalCenter)];
            i++;
        }
        currentFeature++;
    }
 
    faceArray=nil;
    for (NSDictionary *faceParam in faceParameArray) {
        NSLog(@"faceParam: %@", [faceParam description]);
    }
    // MARK: update vi tri cua tung filter sticker ()
//    int i = 0;
//    for (NSDictionary *item in self.stickerConfig[@"items"]) {
//        if([item[@"position"] intValue] >= 10){
//            continue;
//        }
//        if(i == 0){
//            [self.faceWidgetFilter setStickerParams:faceParameArray[i]];
//        }else if(i == 1){
//            [self.faceWidgetFilter1 setStickerParams:faceParameArray[i]];
//        }else if(i == 2){
//            [self.faceWidgetFilter2 setStickerParams:faceParameArray[i]];
//        }else if(i == 3){
//            [self.faceWidgetFilter3 setStickerParams:faceParameArray[i]];
//        }else if(i == 4){
//            [self.faceWidgetFilter4 setStickerParams:faceParameArray[i]];
//        }else if(i == 5){
//            [self.faceWidgetFilter5 setStickerParams:faceParameArray[i]];
//        }
//        i++;
//    }
}

-(CGPoint)midPointWithIndex:(NSInteger)index1 :(NSInteger)index2 :(NSInteger[])points {
    return CGPointMake((points[index1 * 2] + points[index2 * 2]) / 2.0f, (points[index1 * 2 + 1] + points[index2 * 2 + 1]) / 2.0f);
}

-(CGPoint)rotation:(CGPoint)point :(CGPoint)centerPoint :(CGFloat)sin :(CGFloat)cos {
    CGPoint p = CGPointMake(point.x - centerPoint.x, point.y - centerPoint.y);
    point.x = centerPoint.x + (cos * p.x - sin * p.y) ;
    point.y = centerPoint.y + (sin * p.x + cos * p.y);
    return point;
}

-(CGFloat)distance:(CGPoint)point :(CGPoint)point2 {
    CGFloat b = point.y - point2.y;
    CGFloat a = point.x - point2.x;
    CGFloat c = sqrtf(a * a + b * b);
    return c;
}

-(CGPoint)midPoint:(CGPoint)p1 :(CGPoint)p2 {
    return CGPointMake((p1.x + p2.x) / 2.0f, (p1.y + p2.y) / 2.0f);
}


+ (UIImage *)convertImageToGrayScale:(UIImage *)image
{
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    CIContext *context = [CIContext contextWithOptions:nil];
    
    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:@(0.0) forKey:kCIInputSaturationKey];
    
    CIImage *outputImage = filter.outputImage;
    
    CGImageRef cgImageRef = [context createCGImage:outputImage fromRect:outputImage.extent];
    
    UIImage *result = [UIImage imageWithCGImage:cgImageRef];
    CGImageRelease(cgImageRef);
    return result;
}
-(BOOL)isEmpty:(id)value{
    if(value == nil || value == Nil || value == (id)[NSNull null]){
        return YES;
    }
    if ([value respondsToSelector:@selector(count)]) {
        return [value count]<1;
    }else if ([value respondsToSelector:@selector(length)]) {
       return [value length]<1;
    }
    return NO;
}
@end
