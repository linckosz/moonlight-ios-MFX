//
//  StreamView.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
@import AVKit;
#import "ControllerSupport.h"
#import "OnScreenControls.h"
#import "Moonlight-Swift.h"
#import "StreamConfiguration.h"
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@protocol UserInteractionDelegate <NSObject>

- (void) userInteractionBegan;
- (void) userInteractionEnded;

@end

#if TARGET_OS_TV
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate>
#else
@interface StreamView : MTKView  <X1KitMouseDelegate, UITextFieldDelegate,
AVPictureInPictureControllerDelegate,UIPointerInteractionDelegate,AVPictureInPictureSampleBufferPlaybackDelegate>
#endif

- (void) setupStreamView:(ControllerSupport*)controllerSupport
     interactionDelegate:(id<UserInteractionDelegate>)interactionDelegate
                  config:(StreamConfiguration*)streamConfig;
- (void) showOnScreenControls;
- (OnScreenControlsLevel) getCurrentOscState;

#if !TARGET_OS_TV
- (void) updateCursorLocation:(CGPoint)location isMouse:(BOOL)isMouse;
- (CGPoint) adjustCoordinatesForVideoArea:(CGPoint)point;
- (CGSize) getVideoAreaSize;
- (void) openKeyboard;
- (void) closeKeyboard;
- (void) previousMonitor;
- (void) nextMonitor;
#endif

@end
