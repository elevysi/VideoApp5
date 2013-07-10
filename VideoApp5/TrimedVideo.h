//
//  TrimedVideo.h
//  VideoApp5
//
//  Created by Elvis Hatungimana on 6/9/13.
//  Copyright (c) 2013 Elvis Hatungimana. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface TrimedVideo : NSWindowController
{
    AVPlayer *player;
	AVPlayerLayer *playerLayer;
}

@property (retain) AVPlayer *player;
@property (retain) AVPlayerLayer *playerLayer;
@property (assign) double currentTime;
@property (readonly) double duration;
@property (assign) float volume;

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

@property AVMutableComposition *mutableComposition;
@property AVMutableComposition *composition;
@property AVMutableVideoComposition *videoComposition;
@property AVMutableAudioMix *audioMix;

- (id) initWithWindowNibName:(NSString *)windowNibName andComposition:(AVMutableComposition *)mutComposition;

- (IBAction)playPauseToggle:(id)sender;
- (IBAction)fastForward:(id)sender;
- (IBAction)rewind:(id)sender;

@end
