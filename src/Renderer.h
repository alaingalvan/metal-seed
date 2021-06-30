#pragma once

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include "CrossWindow/CrossWindow.h"
#include "CrossWindow/Graphics.h"

#define GLM_FORCE_DEFAULT_ALIGNED_GENTYPES 1
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"

#include <vector>
#include <chrono>
#include <algorithm>
#include <fstream>
#include <iostream>

#include <unistd.h>

// Common Utils

inline std::vector<char> readFile(const std::string& filename) {
	std::string path = filename;
	char pBuf[1024];

	getcwd(pBuf, 1024);
	path = pBuf;
	path += "/";

	path += filename;
	std::ifstream file(path, std::ios::ate | std::ios::binary);
	bool exists = (bool)file;

	if (!exists || !file.is_open()) {
		throw std::runtime_error("failed to open file!");
	}

	size_t fileSize = (size_t)file.tellg();
	std::vector<char> buffer(fileSize);

	file.seekg(0);
	file.read(buffer.data(), fileSize);

	file.close();

	return buffer;
};

template <typename T>
inline T clamp(const T& value, const T& low, const T& high)
{
	return value < low ? low : (value > high ? high : value);
}


// Renderer

class Renderer
{
public:
	Renderer(xwin::Window& window);

	~Renderer();

	// Render onto the render target
	void render();

	// Resize the window and internal data structures
	void resize(unsigned width, unsigned height);

protected:

	// Initialize your Graphics API
	void initializeAPI(xwin::Window& window);

	// Destroy any Graphics API data structures used in this example
	void destroyAPI();

	// Initialize any resources such as VBOs, IBOs, used in this example
	void initializeResources();

	// Destroy any resources used in this example
	void destroyResources();

	// Create graphics API specific data structures to send commands to the GPU
	void createCommands();

	// Set up commands used when rendering frame by this app
	void setupCommands();

	// Destroy all commands
	void destroyCommands();

	// Set up the FrameBuffer
	void initFrameBuffer();

	void destroyFrameBuffer();

	// Set up the RenderPass
	void createRenderPass();

	void createSynchronization();

	// Set up the swapchain
	void setupSwapchain(unsigned width, unsigned height);

	struct Vertex
	{
		float position[3];
		float color[3];
	};

	Vertex mVertexBufferData[3] =
	{
	  { { 1.0f,  -1.0f, 0.0f },{ 1.0f, 0.0f, 0.0f } },
	  { { -1.0f,  -1.0f, 0.0f },{ 0.0f, 1.0f, 0.0f } },
	  { { 0.0f, 1.0f, 0.0f },{ 0.0f, 0.0f, 1.0f } }
	};

	uint32_t mIndexBufferData[3] = { 0, 1, 2 };

	std::chrono::time_point<std::chrono::steady_clock> tStart, tEnd;
	float mElapsedTime = 0.0f;

	// Uniform data
	struct {
		glm::mat4 projectionMatrix;
		glm::mat4 modelMatrix;
		glm::mat4 viewMatrix;
	} uboVS;

	// The device (aka GPU) we're using to render
	id<MTLDevice> mDevice;

	CAMetalLayer* mLayer;
	// The command Queue from which we'll obtain command buffers
	id<MTLCommandQueue> mCommandQueue;

	// The current size of our view so we can use this in our render pipeline
	unsigned mViewportSize[2];

	//Resources
	id<MTLLibrary> vertLibrary;
	id<MTLLibrary> fragLibrary;
	id<MTLFunction> vertexFunction;
	id<MTLFunction> fragmentFunction;
	id<MTLBuffer> mVertexBuffer;
	id<MTLBuffer> mIndexBuffer;
	id<MTLBuffer> mUniformBuffer;
	id<MTLRenderPipelineState> mPipelineState;
	id<MTLCommandBuffer> mCommandBuffer;


};
