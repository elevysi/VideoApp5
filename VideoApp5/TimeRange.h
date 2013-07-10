//
//  TimeRange.h
//  VideoApp5
//
//  Created by Elvis Hatungimana on 6/9/13.
//  Copyright (c) 2013 Elvis Hatungimana. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TimeRange : NSWindowController
{
    NSNotificationCenter  *notificationCenter;
}

//@property ()NSNotificationCenter            *notificationCenter;
@property (weak) IBOutlet NSTextField *startTextField;
@property (weak) IBOutlet NSTextField *endTextField;
@property (weak) IBOutlet NSTextField *durationLabel;

@property(assign)double duration;
@property()NSNumber* startTrimTime;
@property()NSNumber* endTrimTime;

@property(strong)NSMutableDictionary *trimDic;

- (id) initWithWindowNibName:(NSString *)windowNibName andDuration:(double)duration;
- (IBAction)setStartTime:(id)sender;
- (IBAction)setEndTime:(id)sender;
- (IBAction)performTrim:(id)sender;

@end
