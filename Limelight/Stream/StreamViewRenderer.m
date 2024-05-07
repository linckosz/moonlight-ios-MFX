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

@implementation StreamViewRenderer
{
    id<MTLDevice> _device;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    CVMetalTextureCacheRef textureCache;
    id <MTLTexture> _lumaTexture;
    id <MTLTexture> _lumaUpscaledTexture;
    id <MTLTexture> _chromaTexture;
    id <MTLTexture> _chromaUpscaledTexture;
    id <MTLFXSpatialScaler> lumaUpscaler;
    id <MTLFXSpatialScaler> chromaUpscaler;
    
    size_t _lumaTextureInputWidth;
    size_t _lumaTextureInputHeight;
    size_t _chromaTextureInputWidth;
    size_t _chromaTextureInputHeight;
    
    float _resolutionMultiplier;
    BOOL _metalFxEnabled;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
    self = [super init];
    if(self)
    {
        NSError *error;

        _device = view.device;
//        view.framebufferOnly = true;
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

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
        _resolutionMultiplier = 2;
        _metalFxEnabled = false;
    }

    return self;
}

-(id<MTLTexture>) upscalingTexture:(NSInteger) format withWidth:(NSInteger) width withHeight:(NSInteger) height; {
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];

    textureDescriptor.pixelFormat = format;
    textureDescriptor.width = width;
    textureDescriptor.height = height;
    textureDescriptor.storageMode = MTLStorageModePrivate;
    textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    
    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [_device newTextureWithDescriptor:textureDescriptor];
    return texture;
}

-(id<MTLTexture>) texture:(nonnull CVImageBufferRef)imageBuffer withPlane: (size_t) plane formatIn: (NSUInteger) format; {
    if (imageBuffer == nil) {
        return nil;
    }
    
    if (textureCache == nil) {
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil,_device,nil,&textureCache);
    }
    size_t width  = CVPixelBufferGetWidthOfPlane(imageBuffer,plane);
    size_t height = CVPixelBufferGetHeightOfPlane(imageBuffer,plane);
    if (width == 0 || height == 0) {
        return nil;
    }
    if (plane == 0) {
        _lumaTextureInputWidth = width;
        _lumaTextureInputHeight = height;
    }else{
        _chromaTextureInputWidth = width;
        _chromaTextureInputHeight = height;
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
    MTLPixelFormat lumaPixelFormat,chromaPixelFormat;
    switch (CVPixelBufferGetPixelFormatType(buffer)) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            lumaPixelFormat = MTLPixelFormatR8Unorm;
            chromaPixelFormat = MTLPixelFormatRG8Unorm;
            break;
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            lumaPixelFormat = MTLPixelFormatR16Unorm;
            chromaPixelFormat = MTLPixelFormatRG16Unorm;
        case kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarFullRange:
            lumaPixelFormat = MTLPixelFormatR8Unorm;
            chromaPixelFormat = MTLPixelFormatRG8Unorm;
            break;
        default:
            Log(LOG_E, @"Unsupport pixel format");
            return;
    }
    id<MTLTexture> luma = [self texture:buffer withPlane:0 formatIn:lumaPixelFormat];
    id<MTLTexture> chroma = [self texture:buffer withPlane:1 formatIn:chromaPixelFormat];
    
    
    _lumaTexture = luma;
    _chromaTexture = chroma;
    
    [self updateMetalFx];
}
- (void)setResolutionMultiplier:(float)m {
    _resolutionMultiplier = m;
    if (_resolutionMultiplier <= 1) {
        [self setMetalFxEnabled:false];
    }
}
- (void)setMetalFxEnabled:(BOOL)enabled; {
    _metalFxEnabled = enabled;
}

- (void)updateMetalFx; {
    if (_metalFxEnabled && _resolutionMultiplier > 1) {
        if (lumaUpscaler == nil) {
            lumaUpscaler = [self allocMetalFxScaler:MTLPixelFormatR8Unorm withWidth:_lumaTextureInputWidth withHeight:_lumaTextureInputHeight];
            _lumaUpscaledTexture = [self upscalingTexture:MTLPixelFormatR8Unorm withWidth:_lumaTextureInputWidth * _resolutionMultiplier withHeight:_lumaTextureInputHeight * _resolutionMultiplier];
        }
        if (chromaUpscaler == nil) {
            chromaUpscaler = [self allocMetalFxScaler:MTLPixelFormatRG8Unorm withWidth:_chromaTextureInputWidth withHeight:_chromaTextureInputHeight];
            _chromaUpscaledTexture = [self upscalingTexture:MTLPixelFormatRG8Unorm withWidth:_chromaTextureInputWidth * _resolutionMultiplier withHeight:_chromaTextureInputHeight * _resolutionMultiplier];
        }
    }else {
        _lumaUpscaledTexture = nil;
        _chromaUpscaledTexture = nil;
        lumaUpscaler = nil;
        chromaUpscaler = nil;
    }
}

- (id<MTLFXSpatialScaler>)allocMetalFxScaler:(NSInteger)pixelFormat withWidth:(size_t)width withHeight:(size_t)height; {
    MTLFXSpatialScalerDescriptor* descriptor = [MTLFXSpatialScalerDescriptor new ];
    descriptor.inputWidth = width;
    descriptor.inputHeight = height;
    descriptor.outputWidth = width * _resolutionMultiplier;
    descriptor.outputHeight = height * _resolutionMultiplier;
    descriptor.colorProcessingMode = MTLFXSpatialScalerColorProcessingModeLinear;
    descriptor.colorTextureFormat = pixelFormat;
    descriptor.outputTextureFormat = pixelFormat;
    return [descriptor newSpatialScalerWithDevice:_device];
}

- (void)render:(nonnull MTKView*)view {
    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = view.currentDrawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

        [renderEncoder pushDebugGroup:@"RenderStreamFrame"];
        
        [renderEncoder setRenderPipelineState:_pipelineState];
        
        if (_lumaTexture != nil && _chromaTexture != nil) {
            lumaUpscaler.colorTexture = _lumaTexture;
            lumaUpscaler.outputTexture = _lumaUpscaledTexture;
            chromaUpscaler.colorTexture = _chromaTexture;
            chromaUpscaler.outputTexture = _chromaUpscaledTexture;
            
            if (_lumaUpscaledTexture != nil && _chromaUpscaledTexture != nil && _metalFxEnabled && _resolutionMultiplier > 1) {
                [renderEncoder setFragmentTexture:_lumaUpscaledTexture atIndex:0];
                [renderEncoder setFragmentTexture:_chromaUpscaledTexture atIndex:1];
            }else{
                [renderEncoder setFragmentTexture:_lumaTexture atIndex:0];
                [renderEncoder setFragmentTexture:_chromaTexture atIndex:1];
            }
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

        }
        
        [renderEncoder popDebugGroup];
        
        [renderEncoder endEncoding];
        if (_lumaTexture != nil && _chromaTexture != nil && _metalFxEnabled && _resolutionMultiplier > 1) {
            [lumaUpscaler encodeToCommandBuffer:commandBuffer];
            [chromaUpscaler encodeToCommandBuffer:commandBuffer];
        }

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
    
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    @autoreleasepool {
        [self render:view];
    }
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{

}
@end
