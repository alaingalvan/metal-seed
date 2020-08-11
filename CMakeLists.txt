# Project Info

cmake_minimum_required(VERSION 3.8 FATAL_ERROR)
cmake_policy(VERSION 3.8)
project(MetalSeed
        VERSION 1.0.0.0
        LANGUAGES C CXX
)

# =============================================================

# CMake Settings

set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set(CMAKE_SUPPRESS_REGENERATION true)
set(DCMAKE_GENERATOR_PLATFORM "x64")
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
SET(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/..)
SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/..)
SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/..)
SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/..)
SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/..)
SET(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/..)
SET(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/..)
if(NOT CMAKE_DEBUG_POSTFIX)
  set(CMAKE_DEBUG_POSTFIX d)
endif()

# =============================================================

# Options

set(XGFX_API METAL CACHE STRING "Which graphics API to use, defaults to AUTO, can be NOOP, VULKAN, OPENGL, DIRECTX12, or METAL.")
set_property(
    CACHE
    XGFX_API PROPERTY
    STRINGS METAL
)

# =============================================================

# Dependencies

# CrossWindow
message(STATUS "Installing crosswindow via submodule")
add_subdirectory(external/crosswindow)
set_property(TARGET CrossWindow PROPERTY FOLDER "Dependencies")

# CrossWindow-Graphics
message(STATUS "Installing crosswindow-graphics via submodule")
add_subdirectory(external/crosswindow-graphics)

# GLM
message(STATUS "Installing glm via submodule")
set(BUILD_STATIC_LIBS ON)
add_subdirectory(external/glm/glm)
set_property(TARGET glm_static PROPERTY FOLDER "Dependencies")

# =============================================================

# Cross Graphics Dependencies
find_library(XGFX_LIBRARY Metal)

# =============================================================

# Sources

file(GLOB_RECURSE FILE_SOURCES RELATIVE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.h
)

set(ASSETS_PATH ${CMAKE_CURRENT_SOURCE_DIR}/assets)
file(GLOB_RECURSE RESOURCE_FILES RELATIVE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/assets/*
)

# Solution Filters
foreach(source IN LISTS FILE_SOURCES)
    get_filename_component(source_path "${source}" PATH)
    string(REPLACE "/" "\\" source_path_msvc "${source_path}")
    string(REPLACE "src" "" source_path_final "${source_path_msvc}")
    source_group("${source_path_final}" FILES "${source}")
endforeach()

foreach(source IN LISTS RESOURCE_FILES)
    get_filename_component(source_path "${source}" PATH)
    string(REPLACE "/" "\\" source_path_msvc "${source_path}")
    string(REPLACE "src" "" source_path_final "${source_path_msvc}")
    source_group("${source_path_final}" FILES "${source}")
endforeach()

# =============================================================

# Finalize App

xwin_add_executable(
    ${PROJECT_NAME}
    "${FILE_SOURCES};${RESOURCE_FILES}"
)

# =============================================================

# Finish Dependencies

target_link_libraries(
    ${PROJECT_NAME}
    ${XGFX_LIBRARY}
    CrossWindowGraphics
    CrossWindow
    glm_static
)

target_include_directories(
  ${PROJECT_NAME}
  PUBLIC external/glm
)

add_dependencies(
    ${PROJECT_NAME}
    CrossWindowGraphics
    CrossWindow
    glm_static
    
)

target_compile_definitions(
  ${PROJECT_NAME} 
  PUBLIC XGFX_${XGFX_API}=1
)

# =============================================================

# Finish Settings

# Change output dir to bin
set_target_properties(${PROJECT_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/..
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE TRUE
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Alain Galvan"
    RESOURCE "${RESOURCE_FILES}"
)

set_source_files_properties(
    ${ASSETS_PATH} PROPERTIES
    MACOS_PACKAGE_LOCATION Resources)

set_target_properties(${PROJECT_NAME} PROPERTIES MACOS_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/assets/Info.plist)