//
//  StreamViewRenderer.h
//  Moonlight
//
//  Created by TimmyOVO on 25/4/24.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import <MetalKit/MetalKit.h>
#import <MetalFX/MetalFX.h>
@import AVFoundation;
// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface StreamViewRenderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
- (void) updateFrameTexture:(nonnull CVImageBufferRef) imageBuffer;
@end

