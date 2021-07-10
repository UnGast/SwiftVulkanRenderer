import Foundation
import Dispatch
import HID
import Vulkan
import GfxMath

public class VulkanRendererApplication<R: VulkanRenderer> {
    let scene: Scene
    public typealias CreateRendererCallback = (VulkanRendererConfig) throws -> R
    let createRenderer: CreateRendererCallback
    var renderer: VulkanRenderer?

    @Deferred var window: Window
    @Deferred var vulkanInstance: VkInstance
    @Deferred var windowSurface: VLKWindowSurface
    @Deferred var surface: VkSurfaceKHR
    @Deferred public var physicalDevice: VkPhysicalDevice
    @Deferred var queueFamilyIndex: UInt32
    @Deferred public var device: VkDevice
    @Deferred public var queue: VkQueue
    @Deferred var swapchain: VkSwapchainKHR
    @Deferred var swapchainImageFormat: VkFormat
    @Deferred public var swapchainExtent: VkExtent2D
    @Deferred var swapchainImages: [VkImage]
    @Deferred var swapchainImageViews: [VkImageView]

    public var beforeFrame: ((Double) -> ())?

    public init(createRenderer: @escaping CreateRendererCallback, scene: Scene) throws {
        self.scene = scene
        self.createRenderer = createRenderer
        
        Platform.initialize()
        print("Platform version: \(Platform.version)")

        let props = WindowProperties(title: "Title", frame: .init(0, 0, 800, 600))

        self.window = try Window(properties: props,
                                surface: makeVLKSurface)

        guard let windowSurface = window.surface as? VLKWindowSurface else {
            fatalError("incorrect surface")
        }
        self.windowSurface = windowSurface
        self.surface = windowSurface.surface
        self.vulkanInstance = windowSurface.instance

        try pickPhysicalDevice()

        try getQueueFamilyIndex()

        try createDevice()

        try createQueue()

        try createSwapchain()

        try getSwapchainImages()

        try createSwapchainImageViews()
    }

    func createVLKInstance() throws -> VkInstance {
        var hidSurfaceExtensions = VLKWindowSurface.getRequiredInstanceExtensionNames()
        var rawExtensionNames = hidSurfaceExtensions + [
            "VK_KHR_get_physical_device_properties2"
        ]

        // strdup copies the string passed in and returns a pointer to copy; copy not managed by swift -> not deallocated
        var enabledLayerNames = [UnsafePointer<CChar>(strdup("VK_LAYER_KHRONOS_validation"))]

        var extNames = rawExtensionNames.map { UnsafePointer<CChar>(strdup($0)) }

        var applicationInfo = VkApplicationInfo()
        applicationInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
        applicationInfo.pNext = nil
        applicationInfo.apiVersion = makeApiVersion(variant: 0, major: 1, minor: 2, patch: 0)

        var createInfo = VkInstanceCreateInfo(
            sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            pApplicationInfo: &applicationInfo,
            enabledLayerCount: UInt32(enabledLayerNames.count),
            ppEnabledLayerNames: enabledLayerNames,
            enabledExtensionCount: UInt32(rawExtensionNames.count),
            ppEnabledExtensionNames: &extNames
        )

        var instanceOpt: VkInstance?
        let result = vkCreateInstance(&createInfo, nil, &instanceOpt)

        guard let instance = instanceOpt, result == VK_SUCCESS else {
            throw VulkanApplicationError.couldNotCreateInstance
        }

        return instance
    }

    func makeVLKSurface(in window: Window) throws -> VLKWindowSurface {
        return try VLKWindowSurface(in: window, instance: createVLKInstance())
    }

	func pickPhysicalDevice() throws {
        var deviceCount: UInt32 = 0
        vkEnumeratePhysicalDevices(vulkanInstance, &deviceCount, nil)
        var devices = Array(repeating: Optional<VkPhysicalDevice>.none, count: Int(deviceCount))
        vkEnumeratePhysicalDevices(vulkanInstance, &deviceCount, &devices)
        self.physicalDevice = devices[0]!
    }

    func getQueueFamilyIndex() throws {
        var queueFamilyCount = UInt32(0)
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nil)
        var queueFamilyProperties = Array(repeating: VkQueueFamilyProperties(), count: Int(queueFamilyCount))
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, &queueFamilyProperties)

        for (index, properties) in queueFamilyProperties.enumerated() {
            var supported = UInt32(0)
            vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, UInt32(index), surface, &supported)

            if supported > 0 {
                self.queueFamilyIndex = UInt32(index)
                return
            }
        }

        fatalError("no suitable queue family found")
    }

    func createDevice() throws {
        var queuePriorities = [Float(1.0)]
        var queueCreateInfo = VkDeviceQueueCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            queueFamilyIndex: queueFamilyIndex,
            queueCount: 1,
            pQueuePriorities: queuePriorities)

        var physicalDeviceFeatures = VkPhysicalDeviceFeatures()
        physicalDeviceFeatures.samplerAnisotropy = 1

        var extensions = [
            UnsafePointer(strdup("VK_KHR_swapchain")),
            UnsafePointer(strdup("VK_EXT_descriptor_indexing")),
            UnsafePointer(strdup("VK_KHR_maintenance3"))
        ]
        #if os(macOS)
        extensions.append(UnsafePointer(strdup("VK_KHR_portability_subset")))
        #endif

        var features = VkPhysicalDeviceFeatures()
        features.multiDrawIndirect = 1

        var descriptorIndexingFeatures = VkPhysicalDeviceDescriptorIndexingFeatures()
        descriptorIndexingFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES
        descriptorIndexingFeatures.shaderSampledImageArrayNonUniformIndexing = 1
        descriptorIndexingFeatures.runtimeDescriptorArray = 1

        var deviceCreateInfo = VkDeviceCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            pNext: &descriptorIndexingFeatures,
            flags: 0,
            queueCreateInfoCount: 1,
            pQueueCreateInfos: &queueCreateInfo,
            enabledLayerCount: 0,
            ppEnabledLayerNames: nil,
            enabledExtensionCount: UInt32(extensions.count),
            ppEnabledExtensionNames: extensions,
            pEnabledFeatures: &features
            )

        var device: VkDevice? = nil
        vkCreateDevice(physicalDevice, &deviceCreateInfo, nil, &device)
        self.device = device!
    }

    func createQueue() throws {
        var queues = [VkQueue?](repeating: VkQueue(bitPattern: 0), count: 1)
        vkGetDeviceQueue(device, UInt32(queueFamilyIndex), 0, &queues)
        self.queue = queues[0]!
    }

    func createSwapchain() throws {
        var capabilities = VkSurfaceCapabilitiesKHR()
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, &capabilities)
        let surfaceFormat = try selectFormat()

        var compositeAlpha: VkCompositeAlphaFlagBitsKHR = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
        let desiredCompositeAlpha =
            [compositeAlpha, VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR, VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR, VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR]

        for desired in desiredCompositeAlpha {
            if capabilities.supportedCompositeAlpha & desired.rawValue == desired.rawValue {
                compositeAlpha = desired
                break
            }
        }

        self.swapchainImageFormat = R.drawTargetFormat

        var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            pNext: nil,
            flags: 0,
            surface: surface,
            minImageCount: capabilities.minImageCount + 1,
            imageFormat: swapchainImageFormat,
            imageColorSpace: surfaceFormat.colorSpace,
            imageExtent: capabilities.maxImageExtent,
            imageArrayLayers: 1,
            imageUsage: VK_IMAGE_USAGE_STORAGE_BIT.rawValue,
            imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: [],
            preTransform: capabilities.currentTransform,
            compositeAlpha: compositeAlpha,
            presentMode: VK_PRESENT_MODE_IMMEDIATE_KHR,
            clipped: 1,
            oldSwapchain: nil
            )

        var swapchain: VkSwapchainKHR? = nil
        vkCreateSwapchainKHR(device, &swapchainCreateInfo, nil, &swapchain)
        self.swapchain = swapchain!
        self.swapchainExtent = capabilities.maxImageExtent
   }

    func selectFormat() throws -> VkSurfaceFormatKHR {
        var formatsCount: UInt32 = 0
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatsCount, nil)
        var formats = Array(repeating: VkSurfaceFormatKHR(), count: Int(formatsCount))
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatsCount, &formats)

        for format in formats {
            if format.format == VK_FORMAT_B8G8R8A8_SRGB {
                return format
            }
        }

        return formats[0]
    }

    func getSwapchainImages() throws {
        var count: UInt32 = 0
        vkGetSwapchainImagesKHR(device, swapchain, &count, nil)
        var images = [VkImage?](repeating: VkImage(bitPattern: 0), count: Int(count))
        vkGetSwapchainImagesKHR(device, swapchain, &count, &images)
        self.swapchainImages = images.map { $0! }
    }

    func createSwapchainImageViews() throws {
        self.swapchainImageViews = try swapchainImages.map {
            try createSwapchainImageView(image: $0, format: swapchainImageFormat, aspectFlags: VK_IMAGE_ASPECT_COLOR_BIT)
        }
    }

    func createSwapchainImageView(image: VkImage, format: VkFormat, aspectFlags: VkImageAspectFlagBits) throws -> VkImageView {
        var createInfo = VkImageViewCreateInfo(
        sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        pNext: nil,
        flags: 0,
        image: image,
        viewType: VK_IMAGE_VIEW_TYPE_2D,
        format: format,
        components: VkComponentMapping(
            r: VK_COMPONENT_SWIZZLE_IDENTITY,
            g: VK_COMPONENT_SWIZZLE_IDENTITY,
            b: VK_COMPONENT_SWIZZLE_IDENTITY,
            a: VK_COMPONENT_SWIZZLE_IDENTITY
        ),
        subresourceRange: VkImageSubresourceRange(
            aspectMask: aspectFlags.rawValue,
            baseMipLevel: 0,
            levelCount: 1,
            baseArrayLayer: 0,
            layerCount: 1)
        )

        var imageView: VkImageView? = nil
        vkCreateImageView(device, &createInfo, nil, &imageView)

        return imageView!
    }

    func recreateSwapchain() throws {
        swapchainImageViews.forEach { vkDestroyImageView(device, $0, nil) }
        vkDestroySwapchainKHR(device, swapchain, nil)

        try createSwapchain()
        try getSwapchainImages()
        try createSwapchainImageViews()
    }

    public func notifySceneContentsUpdated() throws {
        try renderer?.updateSceneContent()
        try renderer?.updateSceneObjectMeta()
    }

    public func notifySceneObjectInfosUpdated() throws {
        try renderer?.updateSceneObjectMeta()
    }

    func drawFrame() throws {
        guard let renderer = self.renderer else {
            return
        }

        var acquireFenceInfo = VkFenceCreateInfo(
            sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            pNext: nil,
            flags: 0
        )
        var acquireFence: VkFence? = nil
        vkCreateFence(device, &acquireFenceInfo, nil, &acquireFence)

        var currentSwapchainImageIndex: UInt32 = 0
        var acquireResult = vkAcquireNextImageKHR(device, swapchain, 0, nil, acquireFence!, &currentSwapchainImageIndex)

        if acquireResult == VK_ERROR_OUT_OF_DATE_KHR {
            fatalError("swapchain out of date")
        }
        let currentImage = swapchainImages[Int(currentSwapchainImageIndex)]

        var waitFences = [acquireFence]
        vkWaitForFences(device, 1, waitFences, 1, 10000000)

        try renderer.draw(targetIndex: Int(currentSwapchainImageIndex), finishFence: nil)

        try renderer.transitionImageLayout(image: currentImage, format: swapchainImageFormat, oldLayout: VK_IMAGE_LAYOUT_UNDEFINED, newLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR)
        vkDeviceWaitIdle(device)

        var presentSwapchains = [Optional(swapchain)]
        var presentImageIndices = [currentSwapchainImageIndex]
        var presentResult = VkResult(rawValue: 0)
        var presentInfo = VkPresentInfoKHR(
            sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            pNext: nil,
            waitSemaphoreCount: 0,
            pWaitSemaphores: nil,
            swapchainCount: 1,
            pSwapchains: presentSwapchains,
            pImageIndices: presentImageIndices,
            pResults: &presentResult
        )
        vkQueuePresentKHR(queue, &presentInfo)

        vkDeviceWaitIdle(device)
    }

    public func run() throws {
        var event = Event()
        var quit = false

        var frameCount = 0

        var keysActive: [KeyCode: Bool] = [
            .LEFT: false,
            .RIGHT: false,
            .UP: false,
            .DOWN: false
        ]

        func setupRenderer() throws {
            renderer = try createRenderer(VulkanRendererConfig(
                physicalDevice: physicalDevice,
                device: device,
                queueFamilyIndex: queueFamilyIndex,
                queue: queue))

            try renderer?.setupDrawTargets(extent: swapchainExtent, images: swapchainImages, imageViews: swapchainImageViews)
            try renderer?.updateSceneContent()
            try renderer?.updateSceneObjectMeta()
            try renderer?.updateSceneCameraUniforms()
        }
        
        var previousFrameTimestamp = Date.timeIntervalSinceReferenceDate
        var lastFrameDurationStartTimestamp = Date.timeIntervalSinceReferenceDate
        var fiveFramesDuration = 1.0

        func frame() throws {
            let currentFrameTimestamp = Date.timeIntervalSinceReferenceDate

            if frameCount % 5 == 0 {
                fiveFramesDuration = currentFrameTimestamp - lastFrameDurationStartTimestamp 
                lastFrameDurationStartTimestamp = currentFrameTimestamp
                //print("fps", 1 / (fiveFramesDuration / 5))
            }

            let timeSinceLastFrame = currentFrameTimestamp - previousFrameTimestamp
            beforeFrame?(timeSinceLastFrame)

            previousFrameTimestamp = currentFrameTimestamp

            if renderer == nil && frameCount > 10 {
                usleep(2000 * 100)
                try setupRenderer()
                usleep(2000 * 100)
            }

            try renderer?.updateSceneCameraUniforms()
            try drawFrame()

            frameCount += 1

            Events.pumpEvents()

            while Events.pollEvent(&event) {
                switch event.variant {
                case .userQuit:
                    quit = true
                
                case .window:
                    if case let .resizedTo(newSize) = event.window.action {
                        try recreateSwapchain()

                        if renderer == nil {
                            try setupRenderer()
                        }
                    }

                case .pointerMotion:
                    let eventData = event.pointerMotion

                    scene.camera.pitch -= eventData.deltaY / 360
                    scene.camera.pitch = min(89 / 360, max(-89 / 360, scene.camera.pitch))
                    scene.camera.yaw += eventData.deltaX / 360
                
                case .keyboard:
                    let eventData = event.keyboard
                    
                    if let key = eventData.virtualKey {
                        if keysActive[key] != nil {
                            keysActive[key] = eventData.state == .pressed ? true : false
                        }
                    }

                default:
                    break
                }
            }

            var deltaMove = FVec3.zero
            var stepSize: Float = Float(timeSinceLastFrame) * 1 // one unit per second speed
            if keysActive[.UP]! {
                deltaMove += scene.camera.forward * stepSize
            }
            if keysActive[.DOWN]! {
                deltaMove -= scene.camera.forward * stepSize
            }
            if keysActive[.LEFT]! {
                deltaMove -= scene.camera.right * stepSize
            }
            if keysActive[.RIGHT]! {
                deltaMove += scene.camera.right * stepSize
            }
            scene.camera.position += deltaMove

            if quit {
                exit(0)
            } else {
                DispatchQueue.main.async {
                    try! frame()
                }
            }
        }

        DispatchQueue.main.async {
            try! frame()
        }

        #if os(macOS)
        CFRunLoopRun()
        #else
        dispatchMain()
        #endif

        Platform.quit()
    }

    enum VulkanApplicationError: Error {
        case couldNotCreateInstance
    }
}