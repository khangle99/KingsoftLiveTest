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
- (int)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer widgetParams:(NSMutableArray **)params skinItems:(NSMutableArray **)skins meshItems:(NSMutableArray **)meshes;
- (NSArray *)grepFacesForPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

