//
//  AbsoluteTouchHandler.m
//  Moonlight
//
//  Created by TimmyOVO on 3/4/24.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#import "PassthroughTouchHandler.h"

#include <Limelight.h>

@implementation PassthroughTouchHandler {
    StreamView* view;
    NSMutableDictionary* fingers;
    int fingerCounter;
}

- (id)initWithView:(StreamView*)view {
    self = [self init];
    self->view = view;
    self->fingers = [NSMutableDictionary new];
    self->fingerCounter = 0;
    return self;
}

- (uint16_t)getRotationFromAzimuthAngle:(float)azimuthAngle {
    // iOS reports azimuth of 0 when the stylus is pointing west, but Moonlight expects
    // rotation of 0 to mean the stylus is pointing north. Rotate the azimuth angle
    // clockwise by 90 degrees to convert from iOS to Moonlight rotation conventions.
    int32_t rotationAngle = (azimuthAngle - M_PI_2) * (180.f / M_PI);
    if (rotationAngle < 0) {
        rotationAngle += 360;
    }
    return (uint16_t)rotationAngle;
}

- (uint8_t)getTiltFromAltitudeAngle:(float)altitudeAngle {
    // iOS reports an altitude of 0 when the stylus is parallel to the touch surface,
    // while Moonlight expects a tilt of 0 when the stylus is perpendicular to the surface.
    // Subtract the tilt angle from 90 to convert from iOS to Moonlight tilt conventions.
    uint8_t altitudeDegs = abs((int16_t)(altitudeAngle * (180.f / M_PI)));
    return 90 - MIN(90, altitudeDegs);
}

+ (BOOL)isStylusEventSupportByHost {
    return (LiGetHostFeatureFlags() & LI_FF_PEN_TOUCH_EVENTS);
}

- (BOOL)sendStylusEvent:(UITouch*)event {
    uint8_t type;
    
    switch (event.phase) {
        case UITouchPhaseBegan:
            type = LI_TOUCH_EVENT_DOWN;
            break;
        case UITouchPhaseMoved:
            type = LI_TOUCH_EVENT_MOVE;
            break;
        case UITouchPhaseEnded:
            type = LI_TOUCH_EVENT_UP;
            break;
        case UITouchPhaseCancelled:
            type = LI_TOUCH_EVENT_CANCEL;
            break;
        default:
            return YES;
    }

    CGPoint location = [self->view adjustCoordinatesForVideoArea:[event locationInView:self->view]];
    CGSize videoSize = [self->view getVideoAreaSize];
    
    NSString* touchAddr =[NSString stringWithFormat:@"%p", event];
    NSNumber* pointerId = [self->fingers valueForKey:touchAddr];
    if (pointerId == nil) {
        Log(LOG_I,@"Should not reach here ");
        return FALSE;
    }
    
    return LiSendTouchEvent(type, pointerId.intValue,
                            location.x / videoSize.width, location.y / videoSize.height,
                          (event.force / event.maximumPossibleForce) / sin(event.altitudeAngle),
                          0.0f, 0.0f,
                          [self getRotationFromAzimuthAngle:[event azimuthAngleInView:self->view]]);
}

- (BOOL) trySendStylusEvents:(NSSet*) touches {
    if (![PassthroughTouchHandler isStylusEventSupportByHost]){
        return NO;
    }
    for(UITouch* touch in touches){
        if(![self sendStylusEvent:touch]){
            
        }
    }
    return YES;
}

- (void)onLongPressStart:(NSTimer*)timer {
    // Raise the left click and start a right click
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    for(UITouch* touch in touches){
        NSString* touchAddr =[NSString stringWithFormat:@"%p", touch];
        if ([self->fingers valueForKey:touchAddr] == nil){
            [self->fingers setValue:[NSNumber numberWithInt:self->fingerCounter++] forKey:touchAddr];
        }
    }
    
    if ([self trySendStylusEvents:touches]){
        return;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([self trySendStylusEvents:touches]){
        return;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([self trySendStylusEvents:touches]){
        return;
    }
    for(UITouch* touch in touches){
        NSString* touchAddr =[NSString stringWithFormat:@"%p", touch];
        if ([self->fingers valueForKey:touchAddr] != nil){
            [self->fingers removeObjectForKey:touchAddr];
            self->fingerCounter--;
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // Treat this as a normal touchesEnded event
    [self touchesEnded:touches withEvent:event];
}

@end
