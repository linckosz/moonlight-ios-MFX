//
//  StreamViewRenderer.m
//  Moonlight
//
//  Created by TimmyOVO on 25/4/24.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//


#import <simd/simd.h>
#import <ModelIO/ModelIO.h>

#import "StreamViewRenderer.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"

static const NSUInteger MaxBuffersInFlight = 3;

@implementation StreamViewRenderer
{
    id<MTLDevice> _device;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    CVMetalTextureCacheRef textureCache;
    id <MTLTexture> _texture;
    id <MTLTexture> _chromaTexture;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
    self = [super init];
    if(self)
    {
        NSError *error;

        _device = view.device;
        view.framebufferOnly = true;
        view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        view.preferredFramesPerSecond = 120;
        
        // Load all the shader files with a .metal file extension in the project.
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"mapTexture"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"displayTexture"];

        // Configure a pipeline descriptor that is used to create a pipeline state.
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.sampleCount = 1;
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;

        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
                
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

        MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        NSDictionary *textureLoaderOptions =
        @{
          MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
          MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
          };

        _texture = [textureLoader newTextureWithName:@"ColorMap"
                                          scaleFactor:1.0
                                               bundle:nil
                                              options:textureLoaderOptions
                                                error:&error];
        _chromaTexture = [textureLoader newTextureWithName:@"ColorMap"
                                               scaleFactor:1.0
                                                    bundle:nil
                                                   options:textureLoaderOptions
                                                     error:&error];

        if(!_texture || error)
        {
            NSLog(@"Error creating texture %@", error.localizedDescription);
        }
        // Create the command queue
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}
-(id<MTLTexture>) texture:(nonnull CVImageBufferRef)imageBuffer withPlane: (size_t) plane formatIn: (NSUInteger) format; {
    if (imageBuffer == nil) {
        return nil;
    }
    BOOL isPlanar = CVPixelBufferIsPlanar(imageBuffer);
    if (textureCache == nil) {
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil,_device,nil,&textureCache);
    }
//        OSType format = CVPixelBufferGetPixelFormatType(imageBuffer);
    size_t width  = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer,plane) : CVPixelBufferGetWidth(imageBuffer);
    size_t height = isPlanar? CVPixelBufferGetHeightOfPlane(imageBuffer,plane) :CVPixelBufferGetHeight(imageBuffer);
    if (width == 0 || height == 0) {
        return nil;
    }

    CVMetalTextureRef cvTexture;
    CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  textureCache,
                                                  imageBuffer,
                                                  nil,
                                              format,
                                                  width,
                                                  height,
                                              plane,
                                              &cvTexture);
    
    id<MTLTexture> result = CVMetalTextureGetTexture(cvTexture);
    CVBufferRelease(cvTexture);
    return result;
}
- (void) updateFrameTexture:(nonnull CVImageBufferRef) buffer;
{
    id<MTLTexture> luma = [self texture:buffer withPlane:0 formatIn:MTLPixelFormatR8Unorm];
    id<MTLTexture> chroma = [self texture:buffer withPlane:1 formatIn:MTLPixelFormatRG8Unorm];
    _texture = luma;
    _chromaTexture = chroma;
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        [renderEncoder pushDebugGroup:@"RenderStreamFrame"];
        
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setFragmentTexture:_texture atIndex:0];
        [renderEncoder setFragmentTexture:_chromaTexture atIndex:1];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        
        [renderEncoder popDebugGroup];
        
        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{

}
@end
