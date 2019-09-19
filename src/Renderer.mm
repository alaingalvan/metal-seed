#include "Renderer.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

using namespace glm;

Renderer::Renderer(xwin::Window& window)
{
	initializeAPI(window);
	initializeResources();
	setupCommands();
	tStart = std::chrono::high_resolution_clock::now();
}

Renderer::~Renderer()
{
	destroyResources();
	destroyAPI();
}

void Renderer::initializeAPI(xwin::Window& window)
{
	xgfx::createMetalLayer(&window);
	xwin::WindowDelegate& del = window.getDelegate();
	CAMetalLayer* layer = (CAMetalLayer*)del.layer;
	mLayer = layer;
	
	layer.device = MTLCreateSystemDefaultDevice();
	mDevice = layer.device;
	
	// Create the command queue
	mCommandQueue = [mDevice newCommandQueue];
	
	xwin::WindowDesc desc = window.getDesc();
	
	mViewportSize[0] = desc.width;
	mViewportSize[1] = desc.height;
}

void Renderer::destroyAPI()
{
	if (mCommandBuffer != nil)
	{
		[mCommandBuffer release];
	}
	
	[mCommandQueue release];
	
	[mDevice release];
}

void Renderer::initializeResources()
{
	// Create Vertex Buffer
	
	mVertexBuffer = [mDevice newBufferWithLength:sizeof(Vertex) * 3
														options:MTLResourceOptionCPUCacheModeDefault];
	[mVertexBuffer setLabel:@"VBO"];
	memcpy(mVertexBuffer.contents, mVertexBufferData, sizeof(Vertex) * 3);
	
	// Create Index Buffer
	
	mIndexBuffer = [mDevice newBufferWithLength:sizeof(unsigned) * 3
													   options:MTLResourceOptionCPUCacheModeDefault];
	[mIndexBuffer setLabel:@"IBO"];
	memcpy(mIndexBuffer.contents, mIndexBufferData, sizeof(unsigned) * 3);
	
	// Create Uniform Buffer
	mUniformBuffer = [mDevice newBufferWithLength:(sizeof(uboVS) + 255) & ~255
														 options:MTLResourceOptionCPUCacheModeDefault];
	[mUniformBuffer setLabel:@"UBO"];
	
	// Update Uniforms
	float zoom = -2.5f;
	
	// Update matrices
	uboVS.projectionMatrix = glm::perspective(45.0f, (float)mViewportSize[0] / (float)mViewportSize[1], 0.01f, 1024.0f);
	
	uboVS.viewMatrix = glm::translate(glm::identity<mat4>(), vec3(0.0f, 0.0f, zoom));
	
	uboVS.modelMatrix = glm::identity<mat4>();
	
	size_t uboSize = sizeof(uboVS);
	
	memcpy((mUniformBuffer).contents, &uboVS, uboSize);
	
	// Load all the shader files with a .msl file extension in the project
	NSError* err = nil;
	
	// Load shader files, add null terminator to the end.
	std::vector<char> vertSource = readFile("assets/triangle.vert.msl");
	vertSource.emplace_back(0);
	std::vector<char> fragSource = readFile("assets/triangle.frag.msl");
	fragSource.emplace_back(0);
	
	{
		NSString* vertPath = [NSString stringWithCString:vertSource.data() encoding:[NSString defaultCStringEncoding]];
		id<MTLLibrary> vLibrary = [mDevice newLibraryWithSource:vertPath options:nil error:&err];
		vertLibrary = vLibrary;
	}
	
	{
		NSString* fragPath = [NSString stringWithCString:fragSource.data() encoding:[NSString defaultCStringEncoding]];
		id<MTLLibrary> fLibrary = [mDevice newLibraryWithSource:fragPath options:nil error:&err];
		fragLibrary = fLibrary;
	}
	
	// Load the vertex function from the library
	vertexFunction = [vertLibrary newFunctionWithName:@"main0"];
	
	// Load the fragment function from the library
	fragmentFunction = [fragLibrary newFunctionWithName:@"main0"];
	
	// Configure a pipeline descriptor that is used to create a pipeline state
	MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineStateDescriptor.label = @"Simple Pipeline";
	pipelineStateDescriptor.vertexFunction = vertexFunction;
	pipelineStateDescriptor.fragmentFunction = fragmentFunction;
	pipelineStateDescriptor.colorAttachments[0].pixelFormat = ((CAMetalLayer*)mLayer).pixelFormat;
	
	MTLVertexDescriptor* vertexDesc = [MTLVertexDescriptor vertexDescriptor];
	vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
	vertexDesc.attributes[0].offset = 0;
	vertexDesc.attributes[0].bufferIndex = 0;
	vertexDesc.attributes[1].format = MTLVertexFormatFloat3;
	vertexDesc.attributes[1].offset = sizeof(float) * 3;
	vertexDesc.attributes[1].bufferIndex = 0;
	vertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
	vertexDesc.layouts[0].stride = sizeof(Vertex);
	
	pipelineStateDescriptor.vertexDescriptor = vertexDesc;
	NSError* error = nil;
	
	mPipelineState = [mDevice newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
																			error:&error];
	if (!mPipelineState)
	{
		// Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
		//  If the Metal API validation is enabled, we can find out more information about what
		//  went wrong.  (Metal API validation is enabled by default when a debug build is run
		//  from Xcode)
		NSLog(@"Failed to created pipeline state, error %@", error);
		return;
	}
	
}

void Renderer::destroyResources()
{
	[fragmentFunction release];
	[vertexFunction release];
	
	[vertLibrary release];
	[fragLibrary release];
	
	[mVertexBuffer release];
	[mIndexBuffer release];
	[mUniformBuffer release];
	
	[mPipelineState release];
}

void Renderer::resize(unsigned int width, unsigned int height)
{
	mViewportSize[0] = width;
	mViewportSize[1] = height;
}

void Renderer::setupCommands()
{
	// Commands are set at render time
}

void Renderer::render()
{
	// Framelimit set to 60 fps
	tEnd = std::chrono::high_resolution_clock::now();
	float time = std::chrono::duration<float, std::milli>(tEnd - tStart).count();
	if (time < (1000.0f / 60.0f))
	{ return; }
	tStart = std::chrono::high_resolution_clock::now();
	
	// Update uniforms
	
	mElapsedTime += 0.001f * time;
	mElapsedTime = fmodf(mElapsedTime, 6.283185307179586f);
	
	uboVS.modelMatrix = glm::rotate(uboVS.modelMatrix, 0.001f * time, vec3(0.0f, 1.0f, 0.0f));
	memcpy((mUniformBuffer).contents, &uboVS, sizeof(uboVS));
	
	// Create a new command buffer for each render pass to the current drawable
	
	if (mCommandBuffer != nil)
	{ [mCommandBuffer release]; }
	mCommandBuffer = [mCommandQueue commandBuffer];
	mCommandBuffer.label = @"MyCommand";
	
	// Build renderPassDescriptor generated from the view's drawable textures
	id<CAMetalDrawable> drawable = mLayer.nextDrawable;
	
	MTLRenderPassDescriptor* renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
	renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
	renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	
	MTLClearColor clearCol;
	clearCol.red = 0.2;
	clearCol.green = 0.2;
	clearCol.blue = 0.2;
	clearCol.alpha = 1.0;
	renderPassDescriptor.colorAttachments[0].clearColor = clearCol;
	
	if(renderPassDescriptor != nil)
	{
		// Create a render command encoder so we can render into something
		id<MTLRenderCommandEncoder> renderEncoder =
		[mCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
		renderEncoder.label = @"MyRenderEncoder";
		
		// Set the region of the drawable to which we'll draw.
		[renderEncoder setViewport:(MTLViewport){0.0, 0.0, static_cast<float>(mViewportSize[0]), static_cast<float>(mViewportSize[1]), 0.1, 1000.0 }];
		
		[renderEncoder setRenderPipelineState: mPipelineState];
		
		[renderEncoder setCullMode:MTLCullModeNone];
		
		[renderEncoder setVertexBuffer:mUniformBuffer offset:0 atIndex:1];
		
		[renderEncoder setVertexBuffer:mVertexBuffer offset:0 atIndex:0];
		
		
		[renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:3 indexType:MTLIndexTypeUInt32 indexBuffer:mIndexBuffer indexBufferOffset:0];
		
		[renderEncoder endEncoding];
		
		[mCommandBuffer presentDrawable:drawable];
		
		[mCommandBuffer commit];
		
		
	}
	
}
