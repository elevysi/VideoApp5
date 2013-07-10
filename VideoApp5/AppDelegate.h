//
//  AppDelegate.h
//  VideoApp5
//
//  Created by Elvis Hatungimana on 6/9/13.
//  Copyright (c) 2013 Elvis Hatungimana. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "TrimedVideo.h"
#import "TimeRange.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    AVPlayer *player;
	AVPlayerLayer *playerLayer;
    NSNotificationCenter    *notificationCenter;
    
    
    
    
    AVAsset						*asset;
	AVAssetImageGenerator		*imageGenerator;
	CMTimeRange					timeRange;
	NSInteger					filterTag;
	dispatch_queue_t			serializationQueue;
	
	// Only accessed on the main thread
	NSURL						*outputURL;
	BOOL						writingSamples;
//	RWProgressPanelController	*progressPanelController;
    
	// All of these are createed, accessed, and torn down exclusively on the serializaton queue
//	AVAssetReader				*assetReader;
//	AVAssetWriter				*assetWriter;
//	RWSampleBufferChannel		*audioSampleBufferChannel;
//	RWSampleBufferChannel		*videoSampleBufferChannel;
	BOOL						cancelled;
}

@property()double startTrimTime;
@property()double endTrimTime;

//@property ()NSNotificationCenter            *notificationCenter;
@property (retain) AVPlayer *player;
@property (retain) AVPlayerLayer *playerLayer;
@property (assign) double currentTime;
@property (readonly) double duration;
@property (assign) float volume;

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSProgressIndicator *loadingSpinner;
@property (weak) IBOutlet NSTextField *unplayableLabel;
@property (weak) IBOutlet NSTextField *noVideoLabel;
@property (weak) IBOutlet NSView *playerView;

@property (weak) IBOutlet NSButton *playPauseButton;
@property (weak) IBOutlet NSButton *fastForwardButton;
@property (weak) IBOutlet NSButton *rewindButton;
@property (weak) IBOutlet NSSlider *timeSlider;

@property (retain) id timeObserverToken;


@property (strong) AVAsset* theAsset;
@property (strong) TrimedVideo* trimedVideo;

@property (strong) TimeRange* timeRange;

@property AVMutableComposition *mutableComposition;
@property AVMutableComposition *composition;
@property AVMutableVideoComposition *videoComposition;
@property AVMutableAudioMix *audioMix;

- (IBAction)playPauseToggle:(id)sender;
- (IBAction)fastForward:(id)sender;
- (IBAction)rewind:(id)sender;
- (IBAction)openDocument:(id)sender;
- (IBAction)trimHalf:(id)sender;
- (IBAction)trimRange:(id)sender;

- (IBAction)mergeVideos:(id)sender;
- (IBAction)applyFilter:(id)sender;




@property (nonatomic, retain) AVAsset *asset;
//@property (nonatomic) CMTimeRange timeRange2;
//@property (nonatomic, copy) NSURL *outputURL;
//
//@property (nonatomic, retain) IBOutlet NSView *frameView;
//@property (nonatomic, retain) IBOutlet NSPopUpButton *filterPopUpButton;
//
//- (IBAction)start:(id)sender;
//- (IBAction)cancel:(id)sender;
//@property (nonatomic, getter=isWritingSamples) BOOL writingSamples;
@end
