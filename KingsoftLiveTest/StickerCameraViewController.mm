////
////  StickerCameraViewController.m
////  faceCamera
////
////  Created by cain on 16/3/2.
////  Copyright © 2016年 cain. All rights reserved.
////
//
//#import "StickerCameraViewController.h"
//#import "GPUImageFaceWidgetComposeFilter.h"
//#import "GPUImageFilter.h"
//#import "VideoCamera.h"
//#import "Utils.h"
//#import <CoreVideo/CVPixelBuffer.h>
//#import <opencv2/opencv.hpp>
//#include <iostream>
//#include "FaceDetect.h"
//#import <opencv2/videoio/cap_ios.h>
//#import <opencv2/imgcodecs/ios.h>
//
//#define ACTIVE_STICKER_TAG 10001
//#define ICON_TAG 10002
//
//typedef enum{
//    EyeCenter,
//    LeftEyeCenter,
//    RightEyeCenter,
//    MouthMidPoint,
//    MouthLeft,
//    MouthRight,
//    NoseBottom,
//    MouthTop,
//    MouthBottom,
//}Position;
//
//@interface StickerCameraViewController ()<GPUImageVideoCameraDelegate,AVCaptureMetadataOutputObjectsDelegate>{
////    UIView *faceView;
////    UIView *leftEyeView;
////    UIView *leftEye;
////    UIView *mouth;
//}
//
//@property (weak, nonatomic) IBOutlet UIView *cameraView;
//@property (weak, nonatomic) IBOutlet UIButton *switchCamera;
//@property (weak, nonatomic) IBOutlet UIButton *stickerButton;
//@property (weak, nonatomic) IBOutlet UIButton *ratioButton;
//
//@property (weak, nonatomic) IBOutlet UIView *stickerListView;
//@property (weak, nonatomic) IBOutlet UIScrollView *stickerScrollView;
//@property (weak, nonatomic) IBOutlet UIScrollView *stickerTabBarView;
//@property (weak, nonatomic) IBOutlet UILabel *hintLabel;
//@property (weak, nonatomic) IBOutlet UIView *bottomView;
//
//@property BOOL isFrontCamera;
//@property VideoCamera *videoCamera;
//
//@property GPUImageView *GPUView; //preview gpuview
//
//@property GPUImagePicture *placeholderImg;
//
//
//// chua image cua 1 item trong sticker set
//@property GPUImagePicture *faceWidgetImg;
//@property GPUImagePicture *faceWidgetImg1;
//@property GPUImagePicture *faceWidgetImg2;
//@property GPUImagePicture *faceWidgetImg3;
//@property GPUImagePicture *faceWidgetImg4;
//@property GPUImagePicture *faceWidgetImg5;
//
//
//@property GPUImageCropFilter *cropFilter;
//// composer gpuimagepicture ben tren voi video (two input)
//@property GPUImageFaceWidgetComposeFilter *faceWidgetFilter;
//@property GPUImageFaceWidgetComposeFilter *faceWidgetFilter1;
//@property GPUImageFaceWidgetComposeFilter *faceWidgetFilter2;
//@property GPUImageFaceWidgetComposeFilter *faceWidgetFilter3;
//@property GPUImageFaceWidgetComposeFilter *faceWidgetFilter4;
//@property GPUImageFaceWidgetComposeFilter *faceWidgetFilter5;
//
//@property GPUImageFilter *stickerAttachFilter;
//
//// 2 filter danh dau
//@property GPUImageFilter *firstFilter;
//@property GPUImageFilter *lastFilter;
//
//@property NSString *sessionPreset;
//@property NSArray *stickerData;
//@property NSTimeInterval beginTime;
//@property NSTimeInterval lastUpStickerTime;
//@property NSTimeInterval lastDetectorFaceTime;
//@property NSInteger stickerFrameIndex; // index frame cua item trong sticker set
//@property NSInteger mouthStickerFrameIndex; // sticker cua mieng
//@property NSInteger selectedSticker;
//@property (retain, atomic)NSDictionary *stickerConfig;
//@property (retain, atomic)NSString *stickerPath;
//
//@property CGSize cameraSize;
//@property (nonatomic) NSTimer *progressTimer;
//@property CGFloat progress;
//
//@property NSArray *stickersData;
//@property NSMutableDictionary *gpuImagesCache;
//
//@property UIView *actionStickerView;
//@property BOOL detectoredFace;
//
//@property UIImageView *faceAlertView;
//@property NSURL *movieURL;
//@property GPUImageMovieWriter *movieWriter; // local save
//@property FaceDetect *facDetector; // AI detect face
//
//@property BOOL mouthOpening;
//@property CGFloat xcrop;
//@property CGFloat xoffect;
//
//@end
//
//@implementation StickerCameraViewController
//
//- (void)viewDidLoad {
//    
//    [super viewDidLoad];
//    self.lastUpStickerTime = [NSDate timeIntervalSinceReferenceDate];
//    self.gpuImagesCache = [NSMutableDictionary new];
//    
//
//    self.sessionPreset = AVCaptureSessionPreset1280x720;
//    self.cameraSize = CGSizeMake(720,1280);
//    self.isFrontCamera = YES;
//    self.videoCamera = [[VideoCamera alloc] initWithSessionPreset:self.sessionPreset cameraPosition:AVCaptureDevicePositionFront useYuv:NO];
//    self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
//    [self.videoCamera setDelegate:self];
//    
//    self.GPUView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH , SCREEN_HEIGHT)];
//    self.GPUView.backgroundColor = [UIColor redColor];
//    [self.cameraView addSubview:self.GPUView];
//    
//    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];
//    [doubleTap setNumberOfTapsRequired:2];
//    [self.GPUView addGestureRecognizer:doubleTap];
//    
//    self.faceWidgetFilter = [GPUImageFaceWidgetComposeFilter new];
//    self.cropFilter = [[GPUImageCropFilter alloc] init];
//    self.cropFilter.cropRegion = CGRectMake(0, 0, 1.0, 1.0);
//    self.firstFilter = self.cropFilter;
//
//    self.faceWidgetFilter = [GPUImageFaceWidgetComposeFilter new];
//    self.faceWidgetFilter.imgSize = self.cameraSize;
//    self.faceWidgetFilter1 = [GPUImageFaceWidgetComposeFilter new];
//    self.faceWidgetFilter1.imgSize = self.cameraSize;
//    self.faceWidgetFilter2 = [GPUImageFaceWidgetComposeFilter new];
//    self.faceWidgetFilter2.imgSize = self.cameraSize;
//    self.faceWidgetFilter3 = [GPUImageFaceWidgetComposeFilter new];
//    self.faceWidgetFilter3.imgSize = self.cameraSize;
//    self.faceWidgetFilter4 = [GPUImageFaceWidgetComposeFilter new];
//    self.faceWidgetFilter4.imgSize = self.cameraSize;
//    self.faceWidgetFilter5 = [GPUImageFaceWidgetComposeFilter new];
//    self.faceWidgetFilter5.imgSize = self.cameraSize;
//    
//    self.facDetector =[[FaceDetect alloc] init :false];
//    self.placeholderImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"rec"]];
//}
//
//-(void)viewWillAppear:(BOOL)animated{
//    AVAudioSessionRecordPermission audioPermission = [AVAudioSession sharedInstance].recordPermission;
//    AVAuthorizationStatus camPermission = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
//    if(camPermission == AVAuthorizationStatusDenied){
//        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"permission_alert_title" message:@"permission_alert_message" preferredStyle:UIAlertControllerStyleAlert];
//        [alert addAction:[UIAlertAction actionWithTitle:@"permission_alert_ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//            NSURL *settingsUrl = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
//            [[UIApplication sharedApplication] openURL:settingsUrl];
//        }]];
//        [self presentViewController:alert animated:YES completion:^{
//            
//        }];
//    }
//    if(audioPermission == AVAudioSessionRecordPermissionUndetermined){
//        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
//            
//        }];
//    }
//
//    NSString *time = TimeStamp;
//    NSString *path = [NSString stringWithFormat: @"Movie_%@.m4v", time];
//    NSString *moviePath = [NSTemporaryDirectory() stringByAppendingPathComponent:path];
//    unlink([moviePath UTF8String]);
//    self.movieURL        = [NSURL fileURLWithPath:moviePath];
//    self.movieWriter     = [[GPUImageMovieWriter alloc] initWithMovieURL: self.movieURL size:self.cameraSize];
//    self.videoCamera.audioEncodingTarget = self.movieWriter;
//    [self.videoCamera startCameraCapture];
//    [super viewWillAppear:animated];
//}
//
//-(void)viewDidAppear:(BOOL)animated{
//    [super viewDidAppear:animated];
//}
//
//
//
////
////-(void)stickerTap:(UIView *)tapView :(NSDictionary *)sticker{
////    NSString *stickerPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:sticker[@"path"]];
////
////    self.hintLabel.hidden = YES;
////    self.faceAlertView.hidden = YES;
////    if([stickerPath isEqualToString:self.stickerPath]){
////        return;
////    }
////
////    NSDictionary *config = [[Utils readJson:[[NSString alloc] initWithFormat:@"%@/config.json",stickerPath]] mutableCopy];
////    if(!config){
////        return;
////    }
////
////    [self clearFilters];
////    self.stickerConfig = config;
////    self.stickerPath = stickerPath;
////
////    // update UI sticker duoc chon
////    UIView *activeView = [self.view viewWithTag:ACTIVE_STICKER_TAG];
////    if(activeView){
////        [activeView viewWithTag:ICON_TAG].layer.borderWidth = 0;
////        activeView.tag = 0;
////    }
////    tapView.tag = ACTIVE_STICKER_TAG;
////    [tapView viewWithTag:ICON_TAG].layer.borderWidth = 2;
////    [tapView viewWithTag:ICON_TAG].layer.borderColor = [UIColor whiteColor].CGColor;
////
////    // danh dau last filter
////    self.lastFilter = self.firstFilter;
////    // camera -> crop filter (nhung chua crop gi)
////    [self.videoCamera addTarget:self.firstFilter];
////
////    for (NSString *key in [self.gpuImagesCache allKeys]) {
////        GPUImagePicture *gpuImg = [self.gpuImagesCache objectForKey:key];
////        [gpuImg removeAllTargets];
////        [[gpuImg framebufferForOutput] unlock];
////        [gpuImg removeOutputFramebuffer];
////    }
////    [self.gpuImagesCache removeAllObjects];
////
////    NSDictionary *parames = @{@"count" : @"0"}; // empty params
////
////    int i = 0;
////
////    self.faceWidgetImg = self.placeholderImg;
////    self.faceWidgetImg1 = self.placeholderImg;
////    self.faceWidgetImg2 = self.placeholderImg;
////    self.faceWidgetImg3 = self.placeholderImg;
////    self.faceWidgetImg4 = self.placeholderImg;
////    self.faceWidgetImg5 = self.placeholderImg;
////    [self.placeholderImg processImage];
////    self.hintLabel.hidden = YES;
////    for (NSDictionary *item in self.stickerConfig[@"items"]) { // loop qua ds cac item cua sticker set
////
////
////        // wired cac filter sticker truoc, AI se cap nhat vi tri cua sticker sau
////        // moi 1 item la 1 face widget filter, 1 set sticker co the co nhiu item ( o nhieu vi tri)
////        if(i == 0){
////            [self.faceWidgetFilter setStickerParams:parames];
////            [self.lastFilter addTarget:self.faceWidgetFilter]; // video -> faceWidget
////            self.lastFilter = self.faceWidgetFilter;
////            [self.faceWidgetImg addTarget:self.lastFilter atTextureLocation:1]; // sticker picture -> faceWidget
////        }
////        else if(i == 1){
////            [self.lastFilter addTarget:self.faceWidgetFilter1];
////            [self.faceWidgetFilter1 setStickerParams:parames];
////            self.lastFilter = self.faceWidgetFilter1;
////            [self.faceWidgetImg1 addTarget:self.faceWidgetFilter1 atTextureLocation:1];
////        }
////        else if(i == 2){
////            [self.lastFilter addTarget:self.faceWidgetFilter2];
////            [self.faceWidgetFilter2 setStickerParams:parames];
////            self.lastFilter = self.faceWidgetFilter2;
////            [self.faceWidgetImg2 addTarget:self.faceWidgetFilter2 atTextureLocation:1];
////        }
////        else if(i == 3){
////            [self.lastFilter addTarget:self.faceWidgetFilter3];
////            [self.faceWidgetFilter3 setStickerParams:parames];
////            self.lastFilter = self.faceWidgetFilter3;
////            [self.faceWidgetImg3 addTarget:self.faceWidgetFilter3 atTextureLocation:1];
////        }
////        else if(i == 4){
////            [self.lastFilter addTarget:self.faceWidgetFilter4];
////            [self.faceWidgetFilter4 setStickerParams:parames];
////            self.lastFilter = self.faceWidgetFilter4;
////            [self.faceWidgetImg4 addTarget:self.faceWidgetFilter4 atTextureLocation:1];
////        }else if(i == 5){
////            [self.lastFilter addTarget:self.faceWidgetFilter5];
////            [self.faceWidgetFilter5 setStickerParams:parames];
////            self.lastFilter = self.faceWidgetFilter5;
////            [self.faceWidgetImg5 addTarget:self.faceWidgetFilter5 atTextureLocation:1];
////        }
////        i++;
////    }
////
////    // wired filter, nap skin (crd idx file vao facefilter)
////    if(![Utils isEmpty:self.stickerConfig[@"skins"]]){
////        NSDictionary *skin = self.stickerConfig[@"skins"][0];
////        NSString *folderName = skin[@"folderName"];
////        NSString *idxFile = [[NSString alloc] initWithFormat:@"%@/%@/%@.idx",self.stickerPath,folderName,folderName];
////        NSString *crdFile = [[NSString alloc] initWithFormat:@"%@/%@/%@.crd",self.stickerPath,folderName,folderName];
////        NSString *pngFile = [[NSString alloc] initWithFormat:@"%@/%@/%@_000.png",self.stickerPath,folderName,folderName];
////        [self.skinImg removeAllTargets];
////        if([[NSFileManager defaultManager] fileExistsAtPath:pngFile]){
////            self.skinImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageWithContentsOfFile:pngFile]];
////            [self.faceFilter updateWith:crdFile :idxFile];
////            [self.lastFilter addTarget:self.faceFilter atTextureLocation:0];
////            [self.lastFilter addTarget:self.blendfilter atTextureLocation:0];
////            [self.skinImg addTarget:self.faceFilter atTextureLocation:1];
////            [self.skinImg processImage];
////            [self.faceFilter addTarget:self.blendfilter atTextureLocation:1];
////            self.lastFilter = self.blendfilter;
////        }
////    }
////
////    [self.lastFilter addTarget:self.meshFilter];
////    self.lastFilter = self.meshFilter;
////
////    [self.videoCamera addTarget:self.firstFilter];
////    [self.lastFilter addTarget:self.GPUView]; // ra den preview view
////}
//
//#pragma mark - Face Detection Delegate Callback
//- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
////    if(!self.stickerPath){
////        return;
////    }
//    
//    // update vi tri mesh, skin voi AI OpenCV
//    [self grepFacesForSampleBuffer:sampleBuffer];
//
//    // neu khong phat hien image nao k can chay code tao gpuimagepicture sticker tu gif (png)
//    if(!self.detectoredFace){
//        return;
//    }
//    
//    // select image cua item, update vi tri sticker
//    int i = 0;
//    for (NSDictionary *item in self.stickerConfig[@"items"]) { // duyet toan bo item cua sticker set
//        NSInteger useFrameIndex = self.stickerFrameIndex; // vi tri
//        if([item[@"type"] integerValue] == 1 ){ // Type 1, co du dung skill (nhu sticker harley quin)
//            if(self.mouthOpening){
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    self.hintLabel.hidden = YES;
//                });
//                
//                useFrameIndex = self.mouthStickerFrameIndex;
//                self.mouthStickerFrameIndex++;
//                if(self.mouthStickerFrameIndex > [item[@"frames"] intValue]){
//                    self.mouthOpening = false;
//                    self.mouthStickerFrameIndex = 0;
//                }
//            }
//            if(!self.mouthOpening){
//                [self.faceWidgetImg removeAllTargets];
//                self.faceWidgetImg = self.placeholderImg;
//                [self.faceWidgetImg addTarget:self.faceWidgetFilter atTextureLocation:1];
//                [self.faceWidgetImg processImage];
//                i++;
//                continue; // sang item tiep theo khi mieng dong
//            }
//        }
//        // MARK: load anh png vao gpuimagepicture
//        // get anh voi frame dc luu global
//        NSString *path = [[NSString alloc] initWithFormat:@"%@/%@",self.stickerPath,item[@"folderName"]];
//        int index = useFrameIndex % [item[@"frames"] intValue];
//        NSString *fileName = [[NSString alloc] initWithFormat:@"%@/%@_%03d.png",path,item[@"folderName"],index];
//        GPUImagePicture *itemImg;
//        if(![self.gpuImagesCache objectForKey:fileName]){ // neu co cache gpuimagePicture
//            if([[NSFileManager defaultManager] fileExistsAtPath:fileName]){
//                itemImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageWithContentsOfFile:fileName]];
//            }
//            if(!itemImg){
//                continue;
//            }
//            [self.gpuImagesCache setObject:itemImg forKey:fileName];
//        }
//        itemImg = [self.gpuImagesCache objectForKey:fileName];
//
//        // tuy vi tri cua item trong sticker set gan gpuimagepicture thich hop
//        if(i == 0){
//            [self.faceWidgetImg removeAllTargets]; // xoa gpuimagepicture cu
//            self.faceWidgetImg = itemImg; // su dung gpuimagepicture moi
//            [self.faceWidgetImg addTarget:self.faceWidgetFilter atTextureLocation:1]; // overlay len (location 1)
//            [self.faceWidgetImg processImage]; // ban tin hieu gui di
//        }else if(i == 1){
//            [self.faceWidgetImg1 removeAllTargets];
//            self.faceWidgetImg1 = itemImg;
//            [self.faceWidgetImg1 addTarget:self.faceWidgetFilter1 atTextureLocation:1];
//            [self.faceWidgetImg1 processImage];
//        }else if(i == 2){
//            [self.faceWidgetImg2 removeAllTargets];
//            self.faceWidgetImg2 = itemImg;
//            [self.faceWidgetImg2 addTarget:self.faceWidgetFilter2 atTextureLocation:1];
//            [self.faceWidgetImg2 processImage];
//        }else if(i == 3){
//            [self.faceWidgetImg3 removeAllTargets];
//            self.faceWidgetImg3 = itemImg;
//            [self.faceWidgetImg3 addTarget:self.faceWidgetFilter3 atTextureLocation:1];
//            [self.faceWidgetImg3 processImage];
//        }else if(i == 4){
//            [self.faceWidgetImg4 removeAllTargets];
//            self.faceWidgetImg4 = itemImg;
//            [self.faceWidgetImg4 addTarget:self.faceWidgetFilter4 atTextureLocation:1];
//            [self.faceWidgetImg4 processImage];
//        }else if(i == 5){
//            [self.faceWidgetImg5 removeAllTargets];
//            self.faceWidgetImg5 = itemImg;
//            [self.faceWidgetImg5 addTarget:self.faceWidgetFilter5 atTextureLocation:1];
//            [self.faceWidgetImg5 processImage];
//        }
//        i++;
//    }
//    self.stickerFrameIndex ++; // tang index sticker frame
//}
//// MARK: su dung open CV detect face
//- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer{
//    // b1: tao ra anh cv::Mat
//    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CVPixelBufferLockBaseAddress( imageBuffer, 0 );
//    void* bufferAddress;
//    size_t width;
//    size_t height;
//    size_t bytesPerRow;
//    int format_opencv;
//    format_opencv = CV_8UC4;
// 
//    bufferAddress = CVPixelBufferGetBaseAddress(imageBuffer);
//    width = CVPixelBufferGetWidth(imageBuffer);
//    height = CVPixelBufferGetHeight(imageBuffer);
//    bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
//    
//    cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow); // anh cv::Mat
//    CVPixelBufferUnlockBaseAddress( imageBuffer, 0 );
//    
//    // b2: resize va chuyen sang gray image
//    float scale = 0.35;
//    if(self.isFrontCamera){
//        scale = 0.3;
//    }
//    
//    cv::resize(image(cv::Rect(0,160,720,960)),image,cv::Size(scale*image.cols,scale*image.cols * 1.33),0 ,0 ,cv::INTER_NEAREST);
//    __block cv::Mat_<uint8_t> gray_image;
//    cv::cvtColor(image, gray_image, CV_BGR2GRAY); // chuyen sang gray image, de tang toc phan tich
// 
//    // call opencv phan tich mat
//    NSArray *faces = [self.facDetector landmark:gray_image scale:scale lowModel:false isFrontCamera:self.isFrontCamera];
//    gray_image.release();
//    // su dung faces data sau khi tich hop
//    NSLog(@"Count %lu", (unsigned long)faces.count);
//   // [self GPUVCWillOutputFeatures:faces];
//    
//}
//
////UIScrollViewDelegate
//-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
//    if([scrollView isEqual:self.stickerScrollView]){
//        int index = self.stickerScrollView.contentOffset.x / SCREEN_WIDTH;
//        int i = 0;
//        for (UIButton *bt in [self.stickerTabBarView subviews]) {
//            if([bt isKindOfClass:[UIButton class]]){
//                bt.selected = NO;
//            }
//            if(index == i){
//                bt.selected = YES;
//            }
//            i++;
//        }
//    }
//}
//
////AVCaptureMetadataOutputObjectsDelegate
//- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
//}
//
//
////
//- (void)viewDidDisappear:(BOOL)animated{
//    [self.videoCamera removeAllTargets];
//    [self.videoCamera stopCameraCapture];
//    [super viewDidDisappear:animated];
//}
//
//-(void)dealloc{
//    [self.videoCamera removeAllTargets];
//    self.stickerScrollView.delegate = nil;
//    self.videoCamera = nil;
//    [self.firstFilter removeAllTargets];
//    self.firstFilter = nil;
//    [self.cropFilter removeAllTargets];
//    self.cropFilter = nil;
//    for (NSString *key in [self.gpuImagesCache allKeys]) {
//        GPUImagePicture *gpuPic = [self.gpuImagesCache objectForKey:key];
//        [gpuPic removeAllTargets];
//        [[gpuPic framebufferForOutput] unlock];
//        [gpuPic removeOutputFramebuffer];
//    }
//    [self.gpuImagesCache removeAllObjects];
//    self.faceWidgetImg = nil;
//    [[GPUImageContext sharedFramebufferCache] purgeAllUnassignedFramebuffers];
//}
//
//@end
