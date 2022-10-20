//
//  OpenCVWrapper.h
//  KingsoftLiveTest
//
//  Created by Khang L on 18/10/2022.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface OpenCVWrapper : NSObject
@property (retain, atomic)NSDictionary *stickerConfig;
@property CGSize cameraSize;

+ (NSString *)openCVVersionString;
- (void)configure;
- (NSArray *)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (NSArray *)grepFacesForPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

