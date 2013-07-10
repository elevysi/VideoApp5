//
//  AppDelegate.m
//  VideoApp5
//
//  Created by Elvis Hatungimana on 6/9/13.
//  Copyright (c) 2013 Elvis Hatungimana. All rights reserved.
//

#import "AppDelegate.h"
#import <Quartz/Quartz.h>


@protocol RWSampleBufferChannelDelegate;

@interface RWSampleBufferChannel : NSObject
{
@private
	AVAssetReaderOutput		*assetReaderOutput;
	AVAssetWriterInput		*assetWriterInput;
	
	dispatch_block_t		completionHandler;
	dispatch_queue_t		serializationQueue;
	BOOL					finished;  // only accessed on serialization queue
}
- (id)initWithAssetReaderOutput:(AVAssetReaderOutput *)assetReaderOutput assetWriterInput:(AVAssetWriterInput *)assetWriterInput;
@property (nonatomic, readonly) NSString *mediaType;
- (void)startWithDelegate:(id <RWSampleBufferChannelDelegate>)delegate completionHandler:(dispatch_block_t)completionHandler;  // delegate is retained until completion handler is called.  Completion handler is guaranteed to be called exactly once, whether reading/writing finishes, fails, or is cancelled.  Delegate may be nil.
- (void)cancel;
@end


@protocol RWSampleBufferChannelDelegate <NSObject>
@required
- (void)sampleBufferChannel:(RWSampleBufferChannel *)sampleBufferChannel didReadSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end














static void *AVSPPlayerItemStatusContext = &AVSPPlayerItemStatusContext;
static void *AVSPPlayerRateContext = &AVSPPlayerRateContext;
static void *AVSPPlayerLayerReadyForDisplay = &AVSPPlayerLayerReadyForDisplay;

@implementation AppDelegate

@synthesize player;
@synthesize playerLayer;
@synthesize loadingSpinner;
@synthesize unplayableLabel;
@synthesize noVideoLabel;
@synthesize playerView;
@synthesize playPauseButton;
@synthesize fastForwardButton;
@synthesize rewindButton;
@synthesize timeSlider;
@synthesize timeObserverToken;
@synthesize theAsset;
@synthesize mutableComposition;
@synthesize videoComposition;
@synthesize composition;
@synthesize audioMix;


- (id) init
{
   if ( self = [super init])
   {
       notificationCenter = [NSNotificationCenter defaultCenter];
       [notificationCenter addObserver:self
                              selector:@selector(performTrimFromRanges:)
                                  name:@"performTrim"
                                object:nil];
       
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [[[self playerView] layer] setBackgroundColor:CGColorGetConstantColor(kCGColorBlack)];
    [[self noVideoLabel] setHidden:YES];
    [[self unplayableLabel] setHidden:YES];
    [[self playPauseButton] setEnabled:NO];
    [[self fastForwardButton] setEnabled:NO];
    [[self rewindButton] setEnabled:NO];
    [[self timeSlider] setEnabled:NO];
//    [[self loadingSpinner] startAnimation:self];
    
    
}

- (void) applicationWillFinishLaunching:(NSNotification *)notification{
    
}

- (IBAction)playPauseToggle:(id)sender {
    if ([[self player] rate] != 1.f)
	{
		if ([self currentTime] == [self duration])
			[self setCurrentTime:0.f];
		[[self player] play];
	}
	else
	{
		[[self player] pause];
	}
}

- (IBAction)fastForward:(id)sender {
    if ([[self player] rate] < 2.f)
	{
		[[self player] setRate:2.f];
	}
	else
	{
		[[self player] setRate:[[self player] rate] + 2.f];
	}
}

- (IBAction)rewind:(id)sender {
    if ([[self player] rate] > -2.f)
	{
		[[self player] setRate:-2.f];
	}
	else
	{
		[[self player] setRate:[[self player] rate] - 2.f];
	}
}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel         *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    NSURL *url = nil;
    if ([openPanel runModal] == NSFileHandlingPanelOKButton)
    {
        url = [[openPanel URLs]objectAtIndex:0];
        
    }
    if (url)
    {
        // Create the AVPlayer, add rate and status observers
        [self setPlayer:[[AVPlayer alloc] init]];
        [self addObserver:self forKeyPath:@"player.rate"
                  options:NSKeyValueObservingOptionNew
                  context:AVSPPlayerRateContext];
        
        [self addObserver:self
               forKeyPath:@"player.currentItem.status"
                  options:NSKeyValueObservingOptionNew
                  context:AVSPPlayerItemStatusContext];
        
        // Create an asset with our URL, asychronously load its tracks, its duration, and whether it's playable or protected.
        // When that loading is complete, configure a player to play the asset.
//        AVURLAsset *asset = [AVAsset assetWithURL:url];
        
        NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
        AVURLAsset *loadedAsset = [[AVURLAsset alloc] initWithURL:url options:inputOptions];
        
        self.theAsset = loadedAsset;
        NSArray *assetKeysToLoadAndTest = [NSArray arrayWithObjects:@"playable", @"hasProtectedContent", @"tracks", @"duration", nil];
        
        [loadedAsset loadValuesAsynchronouslyForKeys:assetKeysToLoadAndTest completionHandler:^(void) {
            
            // The asset invokes its completion handler on an arbitrary queue when loading is complete.
            // Because we want to access our AVPlayer in our ensuing set-up, we must dispatch our handler to the main queue.
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                [self setUpPlaybackOfAsset:loadedAsset withKeys:assetKeysToLoadAndTest];
                
            });
            
        }];
    }
}


- (void)setUpPlaybackOfAsset:(AVAsset *)loadedAsset withKeys:(NSArray *)keys
{
    // This method is called when the AVAsset for our URL has completing the loading of the values of the specified array of keys.
	// We set up playback of the asset here.
	
	// First test whether the values of each of the keys we need have been successfully loaded.
	for (NSString *key in keys)
	{
		NSError *error = nil;
		
		if ([loadedAsset statusOfValueForKey:key error:&error] == AVKeyValueStatusFailed)
		{
			[self stopLoadingAnimationAndHandleError:error];
			return;
		}
	}
    if (![loadedAsset isPlayable] || [loadedAsset hasProtectedContent])
	{
		// We can't play this asset. Show the "Unplayable Asset" label.
		[self stopLoadingAnimationAndHandleError:nil];
		[[self unplayableLabel] setHidden:NO];
		return;
	}
    
    // We can play this asset.
	// Set up an AVPlayerLayer according to whether the asset contains video.
	if ([[loadedAsset tracksWithMediaType:AVMediaTypeVideo] count] != 0)
	{
		// Create an AVPlayerLayer and add it to the player view if there is video, but hide it until it's ready for display
		AVPlayerLayer *newPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:[self player]];
		[newPlayerLayer setFrame:[[[self playerView] layer] bounds]];
		[newPlayerLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
		[newPlayerLayer setHidden:YES];
		[[[self playerView] layer] addSublayer:newPlayerLayer];
		[self setPlayerLayer:newPlayerLayer];
		
        [self addObserver:self
               forKeyPath:@"playerLayer.readyForDisplay"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:AVSPPlayerLayerReadyForDisplay];
	}
    else
	{
		// This asset has no video tracks. Show the "No Video" label.
		[self stopLoadingAnimationAndHandleError:nil];
		[[self noVideoLabel] setHidden:NO];
	}
    
    // Create a new AVPlayerItem and make it our player's current item.
	AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:loadedAsset];
	[[self player] replaceCurrentItemWithPlayerItem:playerItem];
    
    [self setAsset:loadedAsset];
    
	
	[self setTimeObserverToken:[[self player] addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
		[[self timeSlider] setDoubleValue:CMTimeGetSeconds(time)];
	}]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == AVSPPlayerItemStatusContext)
	{
		AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		BOOL enable = NO;
		switch (status)
		{
			case AVPlayerItemStatusUnknown:
				break;
			case AVPlayerItemStatusReadyToPlay:
				enable = YES;
				break;
			case AVPlayerItemStatusFailed:
				[self stopLoadingAnimationAndHandleError:[[[self player] currentItem] error]];
				break;
		}
		
		[[self playPauseButton] setEnabled:enable];
		[[self fastForwardButton] setEnabled:enable];
		[[self rewindButton] setEnabled:enable];
	}
    else if (context == AVSPPlayerRateContext)
	{
		float rate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		if (rate != 1.f)
		{
			[[self playPauseButton] setTitle:@"Play"];
		}
		else
		{
			[[self playPauseButton] setTitle:@"Pause"];
		}
	}
    else if (context == AVSPPlayerLayerReadyForDisplay)
	{
		if ([[change objectForKey:NSKeyValueChangeNewKey] boolValue] == YES)
		{
			// The AVPlayerLayer is ready for display. Hide the loading spinner and show it.
			[self stopLoadingAnimationAndHandleError:nil];
			[[self playerLayer] setHidden:NO];
		}
	}
    else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)stopLoadingAnimationAndHandleError:(NSError *)error
{
	[[self loadingSpinner] stopAnimation:self];
	[[self loadingSpinner] setHidden:YES];
	if (error)
	{
//		[self presentError:error
//			modalForWindow:[self windowForSheet]
//				  delegate:nil
//		didPresentSelector:NULL
//			   contextInfo:nil];
	}
}

- (void)close
{
	[[self player] pause];
	[[self player] removeTimeObserver:[self timeObserverToken]];
	[self setTimeObserverToken:nil];
	[self removeObserver:self forKeyPath:@"player.rate"];
	[self removeObserver:self forKeyPath:@"player.currentItem.status"];
	if ([self playerLayer])
		[self removeObserver:self forKeyPath:@"playerLayer.readyForDisplay"];
//	[super close];
}

+ (NSSet *)keyPathsForValuesAffectingDuration
{
	return [NSSet setWithObjects:@"player.currentItem", @"player.currentItem.status", nil];
}

- (double)duration
{
	AVPlayerItem *playerItem = [[self player] currentItem];
	
	if ([playerItem status] == AVPlayerItemStatusReadyToPlay)
		return CMTimeGetSeconds([[playerItem asset] duration]);
	else
		return 0.f;
}

- (double)currentTime
{
	return CMTimeGetSeconds([[self player] currentTime]);
}
- (void)setCurrentTime:(double)time
{
	[[self player] seekToTime:CMTimeMakeWithSeconds(time, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (IBAction)trimHalf:(id)sender {
    AVAssetTrack *videoTrack = nil;
    AVAssetTrack *audioTrack = nil;
    
    // Check if the asset contains video and audio tracks
    if ([[[self theAsset] tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        videoTrack = [[[self theAsset] tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    }
    if ([[[self theAsset] tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        audioTrack = [[[self theAsset] tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    }
    
    CMTime insertionPoint = kCMTimeZero;
    NSError * error = nil;
    // Trim to half duration
    double halfDuration = CMTimeGetSeconds([[self theAsset] duration])/2.0;
    CMTime trimmedDuration = CMTimeMakeWithSeconds(halfDuration, 1);
    
    if(!mutableComposition){
        // Create a new composition
        mutableComposition = [AVMutableComposition composition];
        // Insert half time range of the video and audio tracks from AVAsset
        if(videoTrack != nil) {
            AVMutableCompositionTrack *vtrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            [vtrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, trimmedDuration) ofTrack:videoTrack atTime:insertionPoint error:&error];
        }
        if(audioTrack != nil) {
            AVMutableCompositionTrack *atrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [atrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, trimmedDuration) ofTrack:audioTrack atTime:insertionPoint error:&error];
        }
    }
    
    if (!self.trimedVideo) {
        self.trimedVideo = [[TrimedVideo alloc] initWithWindowNibName:@"TrimedVideo" andComposition:mutableComposition];
    }
    [self.trimedVideo showWindow:self];
    
}

- (IBAction)trimRange:(id)sender {
    
    if (!self.timeRange)
    {
        self.timeRange = [[TimeRange alloc] initWithWindowNibName:@"TimeRange"
                                                      andDuration:CMTimeGetSeconds([[self theAsset] duration])];
        
    }
    [[self timeRange] showWindow:self];
}

- (void) performTrimFromRanges:(NSNotification*)notification
{
    NSLog(@"Notification Handler");
    NSMutableDictionary *trimDic = [notification object];
    double start = [[trimDic objectForKey:@"StartTrimime"] doubleValue];
    double end = [[trimDic objectForKey:@"EndTrimTime"] doubleValue];
    
    [self performTrimRange:start andEnd:end];
    
    
    
//    NSLog(@"%f", start);
//    NSLog(@"%f", en   d);
}

- (void) performTrimRange:(double)start andEnd:(double)end
{
    AVAssetTrack *videoTrack = nil;
    AVAssetTrack *audioTrack = nil;
    
    // Check if the asset contains video and audio tracks
    if ([[[self theAsset] tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        videoTrack = [[[self theAsset] tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    }
    if ([[[self theAsset] tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        audioTrack = [[[self theAsset] tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    }
    
    
    CMTime insertionPoint = kCMTimeZero;
//    CMTime insertionPoint = CMTimeMakeWithSeconds(start, 1);
    NSError * error = nil;
    
    double duration = end - start;
    CMTime trimmedDuration = CMTimeMakeWithSeconds(duration, 1);
    CMTime theStart = CMTimeMakeWithSeconds(start, 1);
    
    if (duration > 0)
    {
        if(!mutableComposition){
            // Create a new composition
            mutableComposition = [AVMutableComposition composition];
            // Insert half time range of the video and audio tracks from AVAsset
            if(videoTrack != nil) {
                
                /*
                 insertTimeRange
                 CMTimeRangeMake(theStartTime, durationOfClip)
                 atTime--> when the inserted clip should start within the video Track
                 */
                
                AVMutableCompositionTrack *vtrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
                [vtrack insertTimeRange:CMTimeRangeMake(theStart, trimmedDuration) ofTrack:videoTrack atTime:insertionPoint error:&error];
            }
            if(audioTrack != nil) {
                AVMutableCompositionTrack *atrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                [atrack insertTimeRange:CMTimeRangeMake(theStart, trimmedDuration) ofTrack:audioTrack atTime:insertionPoint error:&error];
            }
        }
        
        if (!self.trimedVideo) {
            self.trimedVideo = [[TrimedVideo alloc] initWithWindowNibName:@"TrimedVideo" andComposition:mutableComposition];
        }
        [self.trimedVideo showWindow:self];
    }
    
    
}

- (IBAction)mergeVideos:(id)sender {
    
    if (self.theAsset)
    {
        NSOpenPanel         *openPanel = [NSOpenPanel openPanel];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setCanChooseDirectories:NO];
        NSURL *url = nil;
        if ([openPanel runModal] == NSFileHandlingPanelOKButton)
        {
            url = [[openPanel URLs]objectAtIndex:0];
            
        }
        if (url)
        {
            
            
            AVURLAsset *firstAsset = [AVAsset assetWithURL:url];
            
            //Insert video at half time
            double halfDuration = CMTimeGetSeconds([firstAsset duration])/2.0;
            CMTime halfWay = CMTimeMakeWithSeconds(halfDuration, 1);
            
            AVMutableComposition* mixComposition = [[AVMutableComposition alloc] init];
            AVMutableCompositionTrack *mixVidTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            AVMutableCompositionTrack *mixAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            
            
            //Insert video track of first track
            
            [mixVidTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, halfWay) ofTrack:[[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
            
            //Insert Audio Track of first Video
            
            [mixAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, halfWay) ofTrack:[[firstAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
            
            
            
            
            //Now we repeat the same process for the 2nd track as we did above for the first track.
            AVAsset* secondAsset = self.theAsset;
            [mixVidTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration) ofTrack:[[secondAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:halfWay error:nil];
            
            //Insert Audio Track of first Video
            
            [mixAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration) ofTrack:[[secondAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:halfWay error:nil];
            
            /*
             Straight Forward Insert Asset in the composition
             
            
            
            [mixComposition insertTimeRange:CMTimeRangeMake(kCMTimeZero, halfWay) ofAsset:firstAsset atTime:kCMTimeZero error:nil];
            [mixComposition insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration) ofAsset:secondAsset atTime:halfWay error:nil];
            
            */
            
            if (!self.trimedVideo) {
                self.trimedVideo = [[TrimedVideo alloc] initWithWindowNibName:@"TrimedVideo" andComposition:mixComposition];
            }
            [self.trimedVideo showWindow:self];
            
            
            
        }
            
            
            
    }
}

//- (IBAction)applyFilter:(id)sender {
//
//    NSURL *fullPath = [NSURL fileURLWithPath:@"/Users/admin/Desktop/producedFile.mov"];
//    
//    NSError *error = nil;
//    
//    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:fullPath fileType:AVFileTypeQuickTimeMovie error:&error];
//    
//    NSParameterAssert(videoWriter);
//    AVAsset *avAsset = self.theAsset;

//    NSDictionary *videoCleanApertureSettings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                                [NSNumber numberWithInt:480], AVVideoCleanApertureWidthKey,
//                                                [NSNumber numberWithInt:640], AVVideoCleanApertureHeightKey,
//                                                [NSNumber numberWithInt:10], AVVideoCleanApertureHorizontalOffsetKey,
//                                                [NSNumber numberWithInt:10], AVVideoCleanApertureVerticalOffsetKey,
//                                                nil];
//    
//    NSDictionary *codecSettings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                   [NSNumber numberWithInt:1960000], AVVideoAverageBitRateKey,
//                                   [NSNumber numberWithInt:24],AVVideoMaxKeyFrameIntervalKey,
//                                   videoCleanApertureSettings, AVVideoCleanApertureKey,
//                                   nil];
//    
//    NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                              AVVideoCodecH264, AVVideoCodecKey,
//                                              codecSettings,AVVideoCompressionPropertiesKey,
//                                              [NSNumber numberWithInt:480], AVVideoWidthKey,
//                                              [NSNumber numberWithInt:640], AVVideoHeightKey,
//                                              nil];

//    AVAssetTrack *videoTrackos = [[[self theAsset] tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
//    CGSize videoSize = [videoTrackos naturalSize];
//    NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                   AVVideoCodecH264, AVVideoCodecKey,
//                                   [NSNumber numberWithInt:videoSize.width], AVVideoWidthKey,
//                                   [NSNumber numberWithInt:videoSize.height], AVVideoHeightKey,
//                                   nil];
//
//    
//    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput
//                                            assetWriterInputWithMediaType:AVMediaTypeVideo
//                                            outputSettings:videoCompressionSettings];
//    
//    
//    
//    NSParameterAssert(videoWriterInput);
//    NSParameterAssert([videoWriter canAddInput:videoWriterInput]);
//    
//    videoWriterInput.expectsMediaDataInRealTime = YES;
//    [videoWriter addInput:videoWriterInput];
//    
//    NSError *aerror = nil;
//    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:avAsset error:&aerror];
//    AVAssetTrack *videoTrack = [[avAsset tracksWithMediaType:AVMediaTypeVideo]objectAtIndex:0];
//    
//    videoWriterInput.transform = videoTrack.preferredTransform;
//    
//    NSDictionary *videoOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
//    
//    
//    AVAssetReaderTrackOutput *asset_reader_output = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:videoOptions];
//    [reader addOutput:asset_reader_output];
//    
//    
//    //audio setup
//    
////    AVAssetWriterInput* audioWriterInput = [AVAssetWriterInput
////                                            assetWriterInputWithMediaType:AVMediaTypeAudio
////                                            outputSettings:nil];
////    
////    
////    AVAssetReader *audioReader = [AVAssetReader assetReaderWithAsset:avAsset error:&error];
////    AVAssetTrack* audioTrack = [[avAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
////    AVAssetReaderOutput *readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
////    
////    [audioReader addOutput:readerOutput];
////    
////    NSParameterAssert(audioWriterInput);
////    NSParameterAssert([videoWriter canAddInput:audioWriterInput]);
////    audioWriterInput.expectsMediaDataInRealTime = NO;
////    [videoWriter addInput:audioWriterInput];
//    [videoWriter startWriting];
//    [videoWriter startSessionAtSourceTime:kCMTimeZero];
//    [reader startReading];
//    
//    
//    
//    CIFilter *exposureFilter = [CIFilter filterWithName: @"CIExposureAdjust"];
//    [exposureFilter setDefaults];
//    
//    
//    
//    dispatch_queue_t _processingQueue = dispatch_queue_create("assetAudioWriterQueue", NULL);
//    
//    [videoWriterInput requestMediaDataWhenReadyOnQueue:_processingQueue usingBlock:
//     ^{
//         while ([videoWriterInput isReadyForMoreMediaData]) {
//             CMTime presentationTime = kCMTimeZero;
//             CMSampleBufferRef sampleBuffer;
//             if ([reader status] == AVAssetReaderStatusReading &&
//                 (sampleBuffer = [asset_reader_output copyNextSampleBuffer])) {
//                 
//                 presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//                 /* Composite over video frame */
//                 
//                 CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//                 
//                 
//                
//                 // Lock the image buffer
//                 CVPixelBufferLockBaseAddress(imageBuffer,0);
//                 
//                 // Get information about the image
//                 uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
//                 size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
//                 size_t width = CVPixelBufferGetWidth(imageBuffer);
//                 size_t height = CVPixelBufferGetHeight(imageBuffer);
//
//                 CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//                 CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
//                 
//                 
//                 /*** Get the Quartz Image ***/
//                 CGImageRef quartzImage = CGBitmapContextCreateImage(newContext);
//                 CIImage *ciImage = [CIImage imageWithCGImage:quartzImage];
//                 [exposureFilter setValue:ciImage forKey:@"inputImage"];
//                 NSNumber *exposureValue = [NSNumber numberWithDouble:10];
//                 [exposureFilter setValue:exposureValue forKey: @"inputEV"];
//                 ciImage = [exposureFilter valueForKey: @"outputImage"];
//                
//                 /*** Draw into context ref to draw over video frame ***/
//                 
//                 /* End composite */
//                 
//                 [videoWriterInput appendSampleBuffer:sampleBuffer];
//                 CFRelease(sampleBuffer);
//                 
//                 
//             }else{
//                 [videoWriterInput markAsFinished];
//                 [videoWriter endSessionAtSourceTime:presentationTime];
//                 
//                 if (![videoWriter finishWriting]) {
//                        NSLog(@"Failed to finish Writing");
//                 }
//             }
//         }
//     }
//     ];
    
    
//}




#pragma mark -
#pragma mark Conversion

+ (CIImage  *)ciImageFromBitmapImageRep:(NSBitmapImageRep*)imageRep
{
    CIImage *image = [[CIImage alloc] initWithBitmapImageRep:imageRep];
    return image;
}

+ (NSImage *) imageFromCIImage:(CIImage *)ciImage
{
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize([ciImage extent].size.width, [ciImage extent].size.height)];
    
    [image addRepresentation:[NSCIImageRep imageRepWithCIImage:ciImage]];
    
    return image;
}

+ (NSImage *)nsImageWithCGImageRef:(CGImageRef)cgImage
{
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSImage *image = [[NSImage alloc] init];
    [image addRepresentation:bitmapRep];
    return image;
}

+ (CGImageRef )cGImageRefWithNSImage:(NSImage *)image
{
    CGImageSourceRef source;
    
    source = CGImageSourceCreateWithData((__bridge CFDataRef)[image TIFFRepresentation], NULL);
    CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
    return maskRef;
}

+ (CGImageRef ) cgImageRefFromCIImage:(CIImage *)ciImage
{
    NSImage *image = [AppDelegate imageFromCIImage:ciImage];
    return [self cGImageRefWithNSImage:image];
}




/*
 Filtering Code
 */
- (IBAction)applyFilter:(id)sender {

    NSURL *fullPath = [NSURL fileURLWithPath:@"/Users/admin/Desktop/producedFile.mov"];

    NSError *error = nil;
    [self startProgressSheetWithURL:fullPath];
    
//    [self setUpReaderAndWriterReturningError:&error];
    
}

- (void)startProgressSheetWithURL:(NSURL *)localOutputURL
{
    AVAsset *localAsset = [self asset];
	[localAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObjects:@"tracks", @"duration", nil] completionHandler:^{
		// Dispatch the setup work to the serialization queue, to ensure this work is serialized with potential cancellation
		dispatch_async(serializationQueue, ^{
			// Since we are doing these things asynchronously, the user may have already cancelled on the main thread.  In that case, simply return from this block
			if (cancelled)
				return;
			
			BOOL success = YES;
			NSError *localError = nil;
			
			success = ([localAsset statusOfValueForKey:@"tracks" error:&localError] == AVKeyValueStatusLoaded);
			if (success)
				success = ([localAsset statusOfValueForKey:@"duration" error:&localError] == AVKeyValueStatusLoaded);
			
			if (success)
			{
                
				// AVAssetWriter does not overwrite files for us, so remove the destination file if it already exists
				NSFileManager *fm = [NSFileManager defaultManager];
				NSString *localOutputPath = [localOutputURL path];
				if ([fm fileExistsAtPath:localOutputPath])
					success = [fm removeItemAtPath:localOutputPath error:&localError];
			}
			
			// Set up the AVAssetReader and AVAssetWriter, then begin writing samples or flag an error
			if (success)
				success = [self setUpReaderAndWriterReturningError:&localError];
			if (success)
//				success = [self startReadingAndWritingReturningError:&localError];
			if (!success)
            {
//				[self readingAndWritingDidFinishSuccessfully:success withError:localError];
            }
		});
	}];
}




- (BOOL)setUpReaderAndWriterReturningError:(NSError **)outError
{
	BOOL success = YES;
	NSError *localError = nil;
	AVAsset *localAsset = [self asset];
    
    NSURL *localOutputURL = [NSURL URLWithString:@"Users/admin/Desktop/output"];
//	NSURL *localOutputURL = [self outputURL];
    
    
    AVAssetWriter* assetWriter;
    AVAssetReader* assetReader;
    
    RWSampleBufferChannel		*audioSampleBufferChannel;
	RWSampleBufferChannel		*videoSampleBufferChannel;
	
	// Create asset reader and asset writer
	assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&localError];
	success = (assetReader != nil);
	if (success)
	{
		assetWriter = [[AVAssetWriter alloc] initWithURL:localOutputURL fileType:AVFileTypeQuickTimeMovie error:&localError];
		success = (assetWriter != nil);
	}
    
	// Create asset reader outputs and asset writer inputs for the first audio track and first video track of the asset
	if (success)
	{
		AVAssetTrack *audioTrack = nil, *videoTrack = nil;
		
		// Grab first audio track and first video track, if the asset has them
		NSArray *audioTracks = [localAsset tracksWithMediaType:AVMediaTypeAudio];
		if ([audioTracks count] > 0)
			audioTrack = [audioTracks objectAtIndex:0];
		NSArray *videoTracks = [localAsset tracksWithMediaType:AVMediaTypeVideo];
		if ([videoTracks count] > 0)
			videoTrack = [videoTracks objectAtIndex:0];
		
		if (audioTrack)
		{
			// Decompress to Linear PCM with the asset reader
			NSDictionary *decompressionAudioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithUnsignedInt:kAudioFormatLinearPCM], AVFormatIDKey,
														nil];
			AVAssetReaderOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:decompressionAudioSettings];
			[assetReader addOutput:output];
			
			AudioChannelLayout stereoChannelLayout = {
				.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
				.mChannelBitmap = 0,
				.mNumberChannelDescriptions = 0
			};
			NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];
            
			// Compress to 128kbps AAC with the asset writer
			NSDictionary *compressionAudioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
													  [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
													  [NSNumber numberWithInteger:128000], AVEncoderBitRateKey,
													  [NSNumber numberWithInteger:44100], AVSampleRateKey,
													  channelLayoutAsData, AVChannelLayoutKey,
													  [NSNumber numberWithUnsignedInteger:2], AVNumberOfChannelsKey,
													  nil];
			AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:[audioTrack mediaType] outputSettings:compressionAudioSettings];
			[assetWriter addInput:input];
			
			// Create and save an instance of RWSampleBufferChannel, which will coordinate the work of reading and writing sample buffers
			audioSampleBufferChannel = [[RWSampleBufferChannel alloc] initWithAssetReaderOutput:output assetWriterInput:input];
		}
		
		if (videoTrack)
		{
			// Decompress to ARGB with the asset reader
			NSDictionary *decompressionVideoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB], (id)kCVPixelBufferPixelFormatTypeKey,
														[NSDictionary dictionary], (id)kCVPixelBufferIOSurfacePropertiesKey,
														nil];
			AVAssetReaderOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:decompressionVideoSettings];
			[assetReader addOutput:output];
			
			// Get the format description of the track, to fill in attributes of the video stream that we don't want to change
			CMFormatDescriptionRef formatDescription = NULL;
			NSArray *formatDescriptions = [videoTrack formatDescriptions];
			if ([formatDescriptions count] > 0)
				formatDescription = (__bridge CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];
			
			// Grab track dimensions from format description
			CGSize trackDimensions = {
				.width = 0.0,
				.height = 0.0,
			};
			if (formatDescription)
				trackDimensions = CMVideoFormatDescriptionGetPresentationDimensions(formatDescription, false, false);
			else
				trackDimensions = [videoTrack naturalSize];
            
			// Grab clean aperture, pixel aspect ratio from format description
			NSDictionary *compressionSettings = nil;
			if (formatDescription)
			{
				NSDictionary *cleanAperture = nil;
				NSDictionary *pixelAspectRatio = nil;
				CFDictionaryRef cleanApertureFromCMFormatDescription = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_CleanAperture);
				if (cleanApertureFromCMFormatDescription)
				{
					cleanAperture = [NSDictionary dictionaryWithObjectsAndKeys:
									 CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureWidth), AVVideoCleanApertureWidthKey,
									 CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureHeight), AVVideoCleanApertureHeightKey,
									 CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureHorizontalOffset), AVVideoCleanApertureHorizontalOffsetKey,
									 CFDictionaryGetValue(cleanApertureFromCMFormatDescription, kCMFormatDescriptionKey_CleanApertureVerticalOffset), AVVideoCleanApertureVerticalOffsetKey,
									 nil];
				}
				CFDictionaryRef pixelAspectRatioFromCMFormatDescription = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_PixelAspectRatio);
				if (pixelAspectRatioFromCMFormatDescription)
				{
					pixelAspectRatio = [NSDictionary dictionaryWithObjectsAndKeys:
										CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing), AVVideoPixelAspectRatioHorizontalSpacingKey,
										CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing), AVVideoPixelAspectRatioVerticalSpacingKey,
										nil];
				}
				
				if (cleanAperture || pixelAspectRatio)
				{
					NSMutableDictionary *mutableCompressionSettings = [NSMutableDictionary dictionary];
					if (cleanAperture)
						[mutableCompressionSettings setObject:cleanAperture forKey:AVVideoCleanApertureKey];
					if (pixelAspectRatio)
						[mutableCompressionSettings setObject:pixelAspectRatio forKey:AVVideoPixelAspectRatioKey];
					compressionSettings = mutableCompressionSettings;
				}
			}
			
			// Compress to H.264 with the asset writer
			NSMutableDictionary *videoSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                  AVVideoCodecH264, AVVideoCodecKey,
                                                  [NSNumber numberWithDouble:trackDimensions.width], AVVideoWidthKey,
                                                  [NSNumber numberWithDouble:trackDimensions.height], AVVideoHeightKey,
                                                  nil];
			if (compressionSettings)
				[videoSettings setObject:compressionSettings forKey:AVVideoCompressionPropertiesKey];
			
			AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:[videoTrack mediaType] outputSettings:videoSettings];
			[assetWriter addInput:input];
			
			// Create and save an instance of RWSampleBufferChannel, which will coordinate the work of reading and writing sample buffers
			videoSampleBufferChannel = [[RWSampleBufferChannel alloc] initWithAssetReaderOutput:output assetWriterInput:input];
		}
	}
	
	if (outError)
		*outError = localError;
	
	return success;
}










static double progressOfSampleBufferInTimeRange(CMSampleBufferRef sampleBuffer, CMTimeRange timeRange)
{
	CMTime progressTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
	progressTime = CMTimeSubtract(progressTime, timeRange.start);
	CMTime sampleDuration = CMSampleBufferGetDuration(sampleBuffer);
	if (CMTIME_IS_NUMERIC(sampleDuration))
		progressTime= CMTimeAdd(progressTime, sampleDuration);
	return CMTimeGetSeconds(progressTime) / CMTimeGetSeconds(timeRange.duration);
}

static void removeARGBColorComponentOfPixelBuffer(CVPixelBufferRef pixelBuffer, size_t componentIndex)
{
	CVPixelBufferLockBaseAddress(pixelBuffer, 0);
	
	size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
	size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
	static const size_t bytesPerPixel = 4;  // constant for ARGB pixel format
	unsigned char *base = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
	for (size_t row = 0; row < bufferHeight; ++row)
	{
		for (size_t column = 0; column < bufferWidth; ++column)
		{
			unsigned char *pixel = base + (row * bytesPerRow) + (column * bytesPerPixel);
			pixel[componentIndex] = 0;
		}
	}
	
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

+ (size_t)componentIndexFromFilterTag:(NSInteger)filterTag
{
	return (size_t)filterTag;  // we set up the tags in the popup button to correspond directly with the index they modify
}

- (void)sampleBufferChannel:(RWSampleBufferChannel *)sampleBufferChannel didReadSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	CVPixelBufferRef pixelBuffer = NULL;
	
	// Calculate progress (scale of 0.0 to 1.0)
//	double progress = progressOfSampleBufferInTimeRange(sampleBuffer, [self timeRange]);
	
	// Grab the pixel buffer from the sample buffer, if possible
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	if (imageBuffer && (CFGetTypeID(imageBuffer) == CVPixelBufferGetTypeID()))
	{
		pixelBuffer = (CVPixelBufferRef)imageBuffer;
		if (filterTag >= 0)  // -1 means "no filtering, please"
			removeARGBColorComponentOfPixelBuffer(pixelBuffer, [[self class] componentIndexFromFilterTag:filterTag]);
	}
	
//	[progressPanelController setPixelBuffer:pixelBuffer forProgress:progress];
}

@end



@interface RWSampleBufferChannel ()
- (void)callCompletionHandlerIfNecessary;  // always called on the serialization queue
@end

@implementation RWSampleBufferChannel

- (id)initWithAssetReaderOutput:(AVAssetReaderOutput *)localAssetReaderOutput assetWriterInput:(AVAssetWriterInput *)localAssetWriterInput
{
	self = [super init];
	
	if (self)
	{
		assetReaderOutput = localAssetReaderOutput;
		assetWriterInput = localAssetWriterInput;
		
		finished = NO;
		NSString *serializationQueueDescription = [NSString stringWithFormat:@"%@ serialization queue", self];
		serializationQueue = dispatch_queue_create([serializationQueueDescription UTF8String], NULL);
	}
	
	return self;
}



- (NSString *)mediaType
{
	return [assetReaderOutput mediaType];
}

- (void)startWithDelegate:(id <RWSampleBufferChannelDelegate>)delegate completionHandler:(dispatch_block_t)localCompletionHandler
{
	completionHandler = [localCompletionHandler copy];  // released in -callCompletionHandlerIfNecessary
    
	[assetWriterInput requestMediaDataWhenReadyOnQueue:serializationQueue usingBlock:^{
		if (finished)
			return;
		
		BOOL completedOrFailed = NO;
		
		// Read samples in a loop as long as the asset writer input is ready
		while ([assetWriterInput isReadyForMoreMediaData] && !completedOrFailed)
		{
			CMSampleBufferRef sampleBuffer = [assetReaderOutput copyNextSampleBuffer];
			if (sampleBuffer != NULL)
			{
				if ([delegate respondsToSelector:@selector(sampleBufferChannel:didReadSampleBuffer:)])
					[delegate sampleBufferChannel:self didReadSampleBuffer:sampleBuffer];
				
				BOOL success = [assetWriterInput appendSampleBuffer:sampleBuffer];
				CFRelease(sampleBuffer);
				sampleBuffer = NULL;
				
				completedOrFailed = !success;
			}
			else
			{
				completedOrFailed = YES;
			}
		}
		
		if (completedOrFailed)
			[self callCompletionHandlerIfNecessary];
	}];
}

- (void)cancel
{
	dispatch_async(serializationQueue, ^{
		[self callCompletionHandlerIfNecessary];
	});
}

- (void)callCompletionHandlerIfNecessary
{
	// Set state to mark that we no longer need to call the completion handler, grab the completion handler, and clear out the ivar
	BOOL oldFinished = finished;
	finished = YES;
    
	if (oldFinished == NO)
	{
		[assetWriterInput markAsFinished];  // let the asset writer know that we will not be appending any more samples to this input
        
		dispatch_block_t localCompletionHandler = completionHandler;
		completionHandler = nil;
        
		if (localCompletionHandler)
		{
			localCompletionHandler();
		}
	}
}

@end


