# SwiftVulkanRenderer

This package provides a basic rasterizing renderer as well as a raytracing renderer written in Swift using the Vulkan API.

Currently I can only confirm that it runs on Ubuntu. On MacOS MoltenVK is missing a feature required by the shaders (descriptor indexing). However with some changes, it should be possible to run it on MacOS as well.

`swift run RasterizationDemo` to see a demo rendering in rasterization mode.

`swift run RaytracingDemo` to see a demo rendering in raytracing mode (using compute shaders). Warning: this might freeze your computer (happened to me sometimes). The application will probably crash after some time.

![demo screenshot](https://github.com/UnGast/SwiftVulkanRenderer/blob/master/screenshot.png)