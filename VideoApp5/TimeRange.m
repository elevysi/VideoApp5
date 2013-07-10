//
//  TimeRange.m
//  VideoApp5
//
//  Created by Elvis Hatungimana on 6/9/13.
//  Copyright (c) 2013 Elvis Hatungimana. All rights reserved.
//

#import "TimeRange.h"

@interface TimeRange ()

@end

@implementation TimeRange

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        self.trimDic = [[NSMutableDictionary alloc] init];
        notificationCenter = [NSNotificationCenter defaultCenter];
        
//        [notificationCenter postNotificationName:@"yeswecan" object:nil];
    }
    
    return self;
}

- (id) initWithWindowNibName:(NSString *)windowNibName andDuration:(double)duration
{
    if (self = [super initWithWindowNibName:windowNibName])
    {
        self.duration = duration;
    }
    return self;
}

- (IBAction)setStartTime:(id)sender {
    self.startTrimTime = [NSNumber numberWithDouble:[self.startTextField doubleValue]];
    [self.trimDic setObject:self.startTrimTime forKey:@"StartTrimime"];
}

- (IBAction)setEndTime:(id)sender {
    self.endTrimTime = [NSNumber numberWithDouble:[self.endTextField doubleValue]];
    [self.trimDic setObject:self.endTrimTime forKey:@"EndTrimTime"];
}

- (IBAction)performTrim:(id)sender {
    if (self.startTextField.stringValue != Nil && self.endTextField.stringValue!= nil)
    {
//        NSLog(@"Not Empty");
        [notificationCenter postNotificationName:@"performTrim"
                                               object:self.trimDic];
//        NSNumber *value = [self.trimDic objectForKey:@"StartTrimime"];
//        NSNumber *endvalue = [self.trimDic objectForKey:@"StartTrimime"];
//        NSLog(@"Start: %f", [value doubleValue]);
//        NSLog(@"End: %f", [endvalue doubleValue]);
    }
    else{
            NSLog(@"Empty");
    }
    
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSString *label = [[NSNumber numberWithDouble:self.duration] stringValue];
    [[self durationLabel] setStringValue:label];

    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
