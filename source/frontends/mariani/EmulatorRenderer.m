//
//  EmulatorRenderer.m
//  Mariani
//

//  Parts of this code are derived from an Apple sample project, whose copyright
//  terms are replicated below:

//  Copyright © 2021 Apple Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.

#import "EmulatorRenderer.h"
#import "ShaderTypes.h"
#import "CommonTypes.h"
#import "AppDelegate.h"

@implementation EmulatorRenderer {
    // The device (aka GPU) used to render
    id<MTLDevice> _device;

    id<MTLRenderPipelineState> _pipelineState;

    // The command Queue used to submit commands.
    id<MTLCommandQueue> _commandQueue;

    // The Metal texture object
    id<MTLTexture> _texture;

    // The Metal buffer that holds the vertex data.
    id<MTLBuffer> _vertices;

    // The number of vertices in the vertex buffer.
    NSUInteger _numVertices;

    // The current size of the view.
    vector_uint2 _viewportSize;
    
    FrameBuffer _frameBuffer;
}

- (void)createTexture {
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    
    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // Set the pixel dimensions of the texture
    textureDescriptor.width = _frameBuffer.pixelWidth + _frameBuffer.borderWidth * 2;
    textureDescriptor.height = _frameBuffer.pixelHeight + _frameBuffer.borderHeight * 2;
    
    // Create the texture from the device by using the descriptor
    _texture = [_device newTextureWithDescriptor:textureDescriptor];
}

- (void)updateTextureWithData:(void *)data {
    // Calculate the number of bytes per row in the image.
    const NSUInteger bytesPerRow = _frameBuffer.bufferWidth * 4;
    
    MTLRegion region = {
        { 0, 0, 0 },    // MTLOrigin
        { _frameBuffer.bufferWidth, _frameBuffer.bufferHeight, 1 }  // MTLSize
    };
    
    // Copy the bytes from the data object into the texture
    [_texture replaceRegion:region
                mipmapLevel:0
                  withBytes:data
                bytesPerRow:bytesPerRow];
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView frameBuffer:(FrameBuffer *)frameBuffer {
    if ((self = [super init]) != nil) {
        _device = mtkView.device;
        
        // keep a copy of the geometry but we don't need the data
        _frameBuffer = *frameBuffer;
        _frameBuffer.data = NULL;
        
        // Create the render pipeline.

        // Load the shaders from the default library
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];

        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Texturing Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

        NSError *error = NULL;
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];

        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

        _commandQueue = [_device newCommandQueue];
    }
    return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    if (_numVertices == 0) {
        // not set up yet, do nothing
        return;
    }
    
    // Create a new command buffer for each render pass to the current drawable
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if (renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }];

        [renderEncoder setRenderPipelineState:_pipelineState];

        [renderEncoder setVertexBuffer:_vertices
                                offset:0
                              atIndex:VertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:VertexInputIndexViewportSize];

        // Set the texture object.  The TextureIndexBaseColor enum value corresponds
        // to the 'colorMap' argument in the 'samplingShader' function because its
        // texture attribute qualifier also uses TextureIndexBaseColor for its index.
        [renderEncoder setFragmentTexture:_texture
                                  atIndex:TextureIndexBaseColor];

        // Draw the triangles.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:_numVertices];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
    
    const BOOL shouldOverscan = [self.delegate shouldOverscan];
    const double borderWidth = shouldOverscan ? _frameBuffer.borderWidth * (1.0 - OVERSCAN) : _frameBuffer.borderWidth;
    const double borderHeight = shouldOverscan ? _frameBuffer.borderHeight * (1.0 - OVERSCAN) : _frameBuffer.borderHeight;
    const double borderWidthRatio = borderWidth / _frameBuffer.bufferWidth;
    const double borderHeightRatio = borderHeight / _frameBuffer.bufferHeight;
    
    // scale the quad to fit inside the view
    const double frameBufferAspectRatio = (double)_frameBuffer.pixelWidth / _frameBuffer.pixelHeight;
    const double viewportAspectRatio = (double)_viewportSize.x / _viewportSize.y;
    double widthScale, heightScale;
    if (frameBufferAspectRatio > viewportAspectRatio) {
        // letterbox
        widthScale = 1.0;
        heightScale = viewportAspectRatio / frameBufferAspectRatio;
    }
    else {
        // pillarbox
        widthScale = frameBufferAspectRatio / viewportAspectRatio;
        heightScale = 1.0;
    }
    const double halfViewWidth = floor((_viewportSize.x * widthScale) / 2);
    const double halfViewHeight = floor((_viewportSize.y * heightScale) / 2);

    // Set up a simple MTLBuffer with vertices which include texture coordinates
    const Vertex quadVertices[] =
    {
        // Pixel positions,                    Texture coordinates
        { {  halfViewWidth, -halfViewHeight }, { 1.f - borderWidthRatio, borderHeightRatio } },
        { { -halfViewWidth, -halfViewHeight }, { borderWidthRatio, borderHeightRatio } },
        { { -halfViewWidth,  halfViewHeight }, { borderWidthRatio, 1.f - borderHeightRatio } },

        { {  halfViewWidth, -halfViewHeight }, { 1.f - borderWidthRatio, borderHeightRatio } },
        { { -halfViewWidth,  halfViewHeight }, { borderWidthRatio, 1.f - borderHeightRatio } },
        { {  halfViewWidth,  halfViewHeight }, { 1.f - borderWidthRatio, 1.f - borderHeightRatio } },
    };

    // Create a vertex buffer, and initialize it with the quadVertices array
    _vertices = [_device newBufferWithBytes:quadVertices
                                     length:sizeof(quadVertices)
                                    options:MTLResourceStorageModeShared];

    // Calculate the number of vertices by dividing the byte length by the size of each vertex
    _numVertices = sizeof(quadVertices) / sizeof(Vertex);
}

@end
