//
//  OpenCVWrapper.h
//  KingsoftLiveTest
//
//  Created by Khang L on 18/10/2022.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface OpenCVWrapper : NSObject
+ (NSString *)openCVVersionString;
- (void)configure;
- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (NSArray *)grepFacesForPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

