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
#import "Utils.h"
#import "Category.h"
#import "MeshItem.h"
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
    //NSLog(@"Count %lu", (unsigned long)faces.count);
    return faces;
}
/// transform sample buffer to number of face detected and output param for 3 kind of filter
- (int)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer widgetParams:(NSMutableArray **)params skinItems:(NSMutableArray **)skins meshItems:(NSMutableArray **)meshes {
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
    
    cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow);
    CVPixelBufferUnlockBaseAddress( imageBuffer, 0 );
 
    float scale = 0.35;
    if(self.isFrontCamera){
        scale = 0.3;
    }
    
    cv::resize(image(cv::Rect(0,160,720,960)),image,cv::Size(scale*image.cols,scale*image.cols * 1.33),0 ,0 ,cv::INTER_NEAREST);
    __block cv::Mat_<uint8_t> gray_image;
    cv::cvtColor(image, gray_image, CV_BGR2GRAY);
 
    NSArray *faces = [self.facDetector landmark:gray_image scale:scale lowModel:false isFrontCamera:self.isFrontCamera];
    gray_image.release();
    
    [self GPUVCWillOutputFeatures:faces widgetParams:params skinItems:skins meshItems:meshes];
    return [faces  count];
}

- (void)GPUVCWillOutputFeatures:(NSArray *)faceArray widgetParams:(NSMutableArray **)params skinItems:(NSMutableArray **)skins meshItems:(NSMutableArray **)meshes
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!faceArray || [faceArray count]<1) {
        NSDictionary *parames = @{ @"count" : @"0"};
//        [self.faceWidgetFilter setStickerParams:parames];
//        [self.faceWidgetFilter2 setStickerParams:parames];
//        [self.faceWidgetFilter3 setStickerParams:parames];
//        [self.faceWidgetFilter4 setStickerParams:parames];
//        [self.faceWidgetFilter5 setStickerParams:parames];
//        [self.faceWidgetFilter6 setStickerParams:parames];
        //[self.meshFilter setItems:nil];
        self.detectoredFace = NO;
        //self.faceImageSkinFilter.items = nil;
        self.mouthOpening = NO;
        //self.mouthStickerFrameIndex = 0;
        return;
    }
    
    self.detectoredFace = YES;
 
    NSMutableDictionary *ftemplate = [[NSMutableDictionary alloc] init];
    [ftemplate setObject:@"0" forKey:@"count"];
    [ftemplate setObject:[NSMutableArray new]  forKey:@"angle"];
    [ftemplate setObject:[NSMutableArray new] forKey:@"point"];
    [ftemplate setObject:[NSMutableArray new] forKey:@"size"];
    
    NSInteger faceCount = [faceArray count];
    // calculate params for filter
    NSMutableArray *faceParameArray = [[NSMutableArray alloc] init];
    NSMutableArray *meshItems = [NSMutableArray new];
    NSMutableArray *skinItems = [NSMutableArray new];
 
    // MARK: process landmark to filter data
    for(NSDictionary *faceInArr in faceArray){ // each face has 132 integer (66 point (x, y))
        
        CGRect faceRect = CGRectFromString(faceInArr[@"rect"]); // face regtangle
        faceRect.size.width = faceRect.size.width * 0.62;
        faceRect.size.height = faceRect.size.width * 0.62;
        
        NSInteger faceLandmarks[136]; // face landmarks (integer)
        NSMutableArray *items = [NSMutableArray new];
        // load landmark to faceArray
        
        // x = index * 2
        // y = (index * 2) + 1
        
        for (int i =0; i < 136; i++) {
            if(i < 120){ // if all point without in mouth (point 0 -> point 59), keep origin value
                faceLandmarks[i] = [[faceInArr[@"shape"] objectAtIndex:i] integerValue];
            }else if(i == 120 || i == 121 || i == 128 ||  i == 129){ //if xy of point 60, point 64, zero out
                // 60 = [0,0], 64 = [0,0]
                faceLandmarks[i] = 0;
                continue;
            }else if (i > 129 ){ // if point from 65 to end (point 67) (from index 130 to 135), clone point 63 to 65
                // 65 = p63, 66 = p64, 67 = p65
                faceLandmarks[i] = [[faceInArr[@"shape"] objectAtIndex:(i-4)] integerValue];
            }else if (i > 121 ){ // if point from 61 (from index 122) to point 63 (to index 127), equal to p60
                // 61 = p60, 62 = p61, 63 = p62 (all is p60)
                // => zero all
                faceLandmarks[i] = [[faceInArr[@"shape"] objectAtIndex:(i-2)] integerValue];
            }
            // point index 60 -> 64 is [0,0]
            
            // zero all từ point index ? check roi xoa logic du
            
            if(i % 2 != 0){ // offset for x
                faceLandmarks[i] +=(160 - self.xoffect);
            }
        }
        int i=0;
 
        CGPoint p27 = CGPointMake(faceLandmarks[27*2], faceLandmarks[27*2+1]);
        CGPoint p30 = CGPointMake(faceLandmarks[30*2], faceLandmarks[30*2+1]);
        CGPoint p33 = CGPointMake(faceLandmarks[33*2], faceLandmarks[33*2+1]);
        CGPoint leftEayCenter = [self midPointWithIndex:36 :39 :faceLandmarks];
        CGPoint rightEayCenter = [self midPointWithIndex:42 :45 :faceLandmarks];
        CGPoint mouthMidPoint = [self midPointWithIndex:51 :57 :faceLandmarks];
        CGPoint mouthLeft = CGPointMake(faceLandmarks[48*2], faceLandmarks[48*2+1]);
        CGPoint mouthRight =CGPointMake(faceLandmarks[54*2], faceLandmarks[54*2+1]);
        CGPoint noseBottom =CGPointMake(faceLandmarks[30*2], faceLandmarks[30*2+1]);
        CGPoint mouthTop = CGPointMake(faceLandmarks[51*2], faceLandmarks[51*2+1]);
        CGPoint mouthBottom = CGPointMake(faceLandmarks[57*2], faceLandmarks[57*2+1]);
        CGPoint eayCenter = p27;
        
        CGFloat b = rightEayCenter.y - leftEayCenter.y;
        CGFloat a = rightEayCenter.x - leftEayCenter.x;
        CGFloat c = sqrtf(a * a + b * b);
        
        // calculate head angle base on eyes
        CGPoint angle = CGPointMake((b/c),a/c);
        float sin = angle.x;
        float cos = angle.y;
        float rad = asin(sin);
 
        NSInteger faceW = faceRect.size.width;
 
        CGFloat mouthW = [self distance:mouthLeft :mouthRight];
        CGFloat noseH = [self distance:p27 :p30];
        
        CGPoint t = [self rotation:CGPointMake(mouthLeft.x + mouthW*0.08, mouthLeft.y) :mouthLeft :sin :cos];
        // point index 60
        faceLandmarks[120] = t.x;
        faceLandmarks[121] = t.y;
        t = [self rotation:CGPointMake(mouthRight.x - mouthW*0.08, mouthRight.y) :mouthRight :sin :cos];
        // point index 64
        faceLandmarks[128] = t.x;
        faceLandmarks[129] = t.y;
 
        // check mouth open
        CGPoint p62 = CGPointMake(faceLandmarks[62*2], faceLandmarks[62*2+1]);
        CGPoint p66 = CGPointMake(faceLandmarks[66*2], faceLandmarks[66*2+1]);
        if([self distance:p62 :p66]/mouthW > 0.3 && !self.mouthOpening){ // ty le giua khoang cach 2 diem mep treb duoi voi mouthwidth > 0.3
            self.mouthOpening = YES;
        }
        
        // Expansion Outer Contour
        i = 0;
        float length = faceW * 0.02;
        for(int i= 0; i < 34;i += 2){
            CGPoint pot = CGPointMake(faceLandmarks[i], faceLandmarks[i+1]);
            float distance = [self distance:pot :p33];
            faceLandmarks[i] = pot.x + (pot.x - p33.x) / distance * length;
            faceLandmarks[i+1] = pot.y + (pot.y - p33.y) / distance * length;
        }
        
        // Outline
        for (int i = 0; i < 32; i+=2) {
            int j = i / 2;
            CGPoint pot = CGPointMake(faceLandmarks[j*2], faceLandmarks[j*2+1]);
            CGPoint npot = CGPointMake(faceLandmarks[j*2+2], faceLandmarks[j*2+3]);
            items[i] = [NSValue valueWithCGPoint:CGPointMake(pot.x, pot.y)];
            items[i+1] = [NSValue valueWithCGPoint:[self midPoint:pot :npot]];
        }

        items[32] = [NSValue valueWithCGPoint:CGPointMake(faceLandmarks[32], faceLandmarks[33])];
        // central part
        for (int i = 17; i < 64; i++) {
            int j = i + 16;
            items[j] = [NSValue valueWithCGPoint:CGPointMake(faceLandmarks[i*2], faceLandmarks[i*2+1])];
        }
        // under the eyebrows
        NSInteger offset = (int)(noseH * 0.10);
        for (int i = 0; i < 4; i++) {
            int j = i + 18;
            CGPoint m = CGPointMake(faceLandmarks[j*2], faceLandmarks[j*2+1]);
            NSInteger useOffset = offset;
            if(i == 3){
                useOffset = offset / 1.3;
            }
            items[64+i] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(m.x, m.y + useOffset) :m :sin :cos]];
        }
        for (int i = 0; i < 4; i++) {
            int j = i + 22;
            CGPoint m = CGPointMake(faceLandmarks[j*2], faceLandmarks[j*2+1]);
            NSInteger useOffset = offset;
            if(i == 3){
                useOffset = offset / 1.3;
            }
            items[68+i] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(m.x, m.y + useOffset) :m :sin :cos]];
        }
        
        // left eye center
        items[72] = [NSValue valueWithCGPoint:[self midPointWithIndex:37 :38 :faceLandmarks]];
        items[73] = [NSValue valueWithCGPoint:[self midPointWithIndex:40 :41 :faceLandmarks]];
        items[74] = [NSValue valueWithCGPoint:[self midPointWithIndex:36 :39 :faceLandmarks]];
        items[75] = [NSValue valueWithCGPoint:[self midPointWithIndex:43 :44 :faceLandmarks]];
        items[76] = [NSValue valueWithCGPoint:[self midPointWithIndex:47 :46 :faceLandmarks]];
        items[77] = [NSValue valueWithCGPoint:[self midPointWithIndex:42 :45 :faceLandmarks]];
        
        // upper part of nose left and right
        items[78] = [NSValue valueWithCGPoint:[self midPointWithIndex:39 :27 :faceLandmarks]];
        items[79] = [NSValue valueWithCGPoint:[self midPointWithIndex:42 :27 :faceLandmarks]];
        CGPoint p29 = CGPointMake(faceLandmarks[29*2], faceLandmarks[29*2+1]);
        CGPoint p31 = CGPointMake(faceLandmarks[31*2], faceLandmarks[31*2+1]);
        CGPoint p35 = CGPointMake(faceLandmarks[35*2], faceLandmarks[35*2+1]);

        items[80] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p29.x - noseH/6., p29.y + noseH/12.) :p29 :sin :cos]];
        items[81] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p29.x + noseH/6, p29.y + noseH/12.) :p29 :sin :cos]];
        items[82] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p31.x - noseH /16., p31.y - noseH / 16.) :p31 :sin :cos]];
        items[83] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p35.x + noseH /16., p35.y - noseH / 16.) :p35 :sin :cos]];
        
        for (int i = 0; i < 20; i++) {
            int j = i + 48;
            items[84+i] = [NSValue valueWithCGPoint:CGPointMake(faceLandmarks[j*2], faceLandmarks[j*2+1])];
        }
        
        // two points below the eyes
        items[104] = [NSValue valueWithCGPoint:[self midPointWithIndex:38 :41 :faceLandmarks]];
        items[105] = [NSValue valueWithCGPoint:[self midPointWithIndex:44 :47 :faceLandmarks]];
        // cheek sides
        CGPoint p2 = CGPointMake(faceLandmarks[2*2], faceLandmarks[2*2+1]);
        CGPoint p14 = CGPointMake(faceLandmarks[14*2], faceLandmarks[14*2+1]);
        CGPoint pot = CGPointMake(p31.x - [self distance:p31 :p2] / 1.5, p31.y);
        items[106] = [NSValue valueWithCGPoint:[self rotation:pot :p31 :sin :cos]];
        pot = CGPointMake(p35.x + [self distance:p35 :p14] / 1.5, p35.y);
        items[107] = [NSValue valueWithCGPoint:[self rotation:pot :p35 :sin :cos]];
        // the forehead
        CGPoint p17 = CGPointMake(faceLandmarks[17*2], faceLandmarks[17*2+1]);
        CGPoint p19 = CGPointMake(faceLandmarks[19*2], faceLandmarks[19*2+1]);
        CGPoint p20 = CGPointMake(faceLandmarks[20*2], faceLandmarks[20*2+1]);
        CGPoint p23 = CGPointMake(faceLandmarks[23*2], faceLandmarks[23*2+1]);
        CGPoint p24 = CGPointMake(faceLandmarks[24*2], faceLandmarks[24*2+1]);

        CGPoint p26 = CGPointMake(faceLandmarks[26*2], faceLandmarks[26*2+1]);
        CGPoint p39 = CGPointMake(faceLandmarks[39*2], faceLandmarks[39*2+1]);
        CGPoint p42 = CGPointMake(faceLandmarks[42*2], faceLandmarks[42*2+1]);
        
        CGPoint p110 = [self midPoint:p39 :p42];
        p110.y -= faceW * 0.8;
 
        items[108] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p17.x , p110.y) :p27 :sin :cos]];
        items[109] = [NSValue valueWithCGPoint:[self rotation:CGPointMake((p19.x + p20.x) / 2., p110.y) :p27 :sin :cos]];
        items[110] = [NSValue valueWithCGPoint:[self rotation:p110 :p27 :sin :cos]];
        items[111] = [NSValue valueWithCGPoint:[self rotation:CGPointMake((p23.x + p24.x) / 2., p110.y) :p27 :sin :cos]];
        items[112] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p26.x, p110.y) :p27 :sin :cos]];

        // MARK: Face Skin Image Params
        i = 0;
        float halfW = self.cameraSize.width /2.;
        float halfH = self.cameraSize.height /2.;
        NSMutableArray *formatedFace = [NSMutableArray new];
        for(NSValue *val in items) {
            CGPoint point = [val CGPointValue];
            formatedFace[i] = [NSValue valueWithCGPoint:CGPointMake((point.x - halfW)/halfW,(point.y - halfH)/halfH)];
            i++;
        }
        
        formatedFace[113] = [NSValue valueWithCGPoint:CGPointMake(-1.,-1.)];
        formatedFace[114] = [NSValue valueWithCGPoint:CGPointMake(0.,-1.)];
        formatedFace[115] = [NSValue valueWithCGPoint:CGPointMake(1.,-1.)];
        formatedFace[116] = [NSValue valueWithCGPoint:CGPointMake(-1.,0.)];
        formatedFace[117] = [NSValue valueWithCGPoint:CGPointMake(1.,0.)];
        formatedFace[118] = [NSValue valueWithCGPoint:CGPointMake(-1.,1.)];
        formatedFace[119] = [NSValue valueWithCGPoint:CGPointMake(0.,1.)];
        formatedFace[120] = [NSValue valueWithCGPoint:CGPointMake(1.,1.)];
        [skinItems addObject:formatedFace];
        
        // MARK: Mesh Params
        if(![Utils isEmpty:self.stickerConfig[@"meshs"]]){
            float halfW = self.cameraSize.width / 2.;
            float halfH = self.cameraSize.height / 2;
            float faceDegree = rad;
            float radius = faceRect.size.width / self.cameraSize.width;
            float faceRatio = 0.1;
            
            for (NSDictionary *item in self.stickerConfig[@"meshs"]) {
                UIEdgeInsets insert = UIEdgeInsetsFromString(item[@"insert"]);
                float itemRadius = radius * [item[@"radius"] floatValue] * 2;
                CGPoint point;
                switch ([item[@"position"] intValue]) {
                    case EyeCenter:
                        point = eayCenter;
                        break;
                    case LeftEyeCenter:
                        point = leftEayCenter;
                        break;
                    case RightEyeCenter:
                        point = rightEayCenter;
                        break;
                    case MouthMidPoint:
                        point = mouthMidPoint;
                        break;
                    case MouthLeft:
                        point = mouthLeft;
                        break;
                    case MouthRight:
                        point = mouthRight;
                        break;
                    case NoseBottom:
                        point = noseBottom;
                        break;
                    case MouthTop:
                        point = mouthTop;
                        break;
                    case MouthBottom:
                        point = mouthBottom;
                        break;
                    default:
                        break;
                }
                
                CGPoint offsetSize = CGPointMake(insert.left * faceRect.size.width, insert.top * faceRect.size.height);
                CGPoint itemPoint;
                CGPoint itemSize = offsetSize;
                itemSize.x = (cos * offsetSize.x - sin * offsetSize.y);
                itemSize.y = (sin * offsetSize.x + cos * offsetSize.y);
                itemPoint = CGPointMake((point.x - itemSize.x - halfW)/halfW,(point.y - itemSize.y - halfH)/halfH );
                [meshItems addObject:[MeshItem itemWith:[item[@"type"] intValue] :[item[@"strength"] floatValue] :itemPoint : itemRadius :[item[@"direction"] intValue] :faceDegree :faceRatio]];
            }
        }
        
        i = 0;
        if([Utils isEmpty:self.stickerConfig[@"items"]]){
            continue;
        }
        // MARK: Widget Params
        for (NSDictionary *item in self.stickerConfig[@"items"]) {
            if([item[@"position"] intValue] >= 10){
                continue;
            }
            NSMutableDictionary *faceParames = [ftemplate mutableDeepCopy];
            [faceParameArray addObject:faceParames];
            faceParames[@"count"] = @(faceCount);
            CGSize stickSize = CGSizeMake([item[@"width"] floatValue],[item[@"height"] floatValue]);
            int position = [item[@"position"] intValue];
            UIEdgeInsets insert = UIEdgeInsetsFromString(item[@"insert"]);
            CGPoint sizePoint;
            CGPoint center = CGPointMake(faceLandmarks[30*2], faceLandmarks[30*2+1]);
            
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
    }

    *skins = skinItems;
    *meshes = meshItems;
    
    faceArray=nil;
    *params = faceParameArray;
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

//+ (UIImage *)convertImageToGrayScale:(UIImage *)image
//{
//    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
//    CIContext *context = [CIContext contextWithOptions:nil];
//
//    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
//    [filter setValue:inputImage forKey:kCIInputImageKey];
//    [filter setValue:@(0.0) forKey:kCIInputSaturationKey];
//
//    CIImage *outputImage = filter.outputImage;
//
//    CGImageRef cgImageRef = [context createCGImage:outputImage fromRect:outputImage.extent];
//
//    UIImage *result = [UIImage imageWithCGImage:cgImageRef];
//    CGImageRelease(cgImageRef);
//    return result;
//}
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
