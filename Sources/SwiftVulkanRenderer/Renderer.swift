import Foundation
import HID
import Vulkan

public class VulkanRenderer {
  let instance: VkInstance
  let surface: VkSurfaceKHR

  @Deferred var physicalDevice: VkPhysicalDevice
  @Deferred var queueFamilyIndex: UInt32
  @Deferred var device: VkDevice
  @Deferred var queue: VkQueue
  @Deferred var swapchain: VkSwapchainKHR
  @Deferred var swapchainImages: [VkImage]

  public init(instance: VkInstance, surface: VkSurfaceKHR) throws {
    self.instance = instance
    self.surface = surface

    try pickPhysicalDevice()

    try getQueueFamilyIndex()

    try createDevice()

    try createQueue()

    try createSwapchain()

    try getSwapchainImages()
  }

  func pickPhysicalDevice() throws {
    var deviceCount: UInt32 = 0
    vkEnumeratePhysicalDevices(instance, &deviceCount, nil)
    var devices = Array(repeating: Optional<VkPhysicalDevice>.none, count: Int(deviceCount))
    vkEnumeratePhysicalDevices(instance, &deviceCount, &devices)
    self.physicalDevice = devices[0]!
  }

  func getQueueFamilyIndex() throws {
    /*var queueFamilyIndex: UInt32?
    for properties in physicalDevice.queueFamilyProperties {
      if try! physicalDevice.hasSurfaceSupport(
        for: properties,
        surface:
          surface
      ) && properties.queueCount & QueueFamilyProperties.Flags.graphicsBit.rawValue == QueueFamilyProperties.Flags.graphicsBit.rawValue {
        queueFamilyIndex = properties.index
      }
    }

    guard let queueFamilyIndexUnwrapped = queueFamilyIndex else {
      throw VulkanRendererError.noSuitableQueueFamily
    }*/

    self.queueFamilyIndex = 0 // TODO: GENERALIZE
    //self.queueFamilyIndex = queueFamilyIndexUnwrapped
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

    let extensions = [UnsafePointer(strdup("VK_KHR_swapchain"))]

    var deviceCreateInfo = VkDeviceCreateInfo(
      sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
      pNext: nil,
      flags: 0,
      queueCreateInfoCount: 1,
      pQueueCreateInfos: &queueCreateInfo,
      enabledLayerCount: 0,
      ppEnabledLayerNames: nil,
      enabledExtensionCount: UInt32(extensions.count),
      ppEnabledExtensionNames: extensions,
      pEnabledFeatures: nil
    )

    var device: VkDevice? = nil
    vkCreateDevice(physicalDevice, &deviceCreateInfo, nil, &device)
    self.device = device!

    /*self.device = try physicalDevice.createDevice(
      createInfo: DeviceCreateInfo(
        flags: .none,
        queueCreateInfos: [queueCreateInfo],
        enabledLayers: [],
        enabledExtensions: ["VK_KHR_swapchain"],
        enabledFeatures: physicalDeviceFeatures))*/
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

    var swapchainCreateInfo = VkSwapchainCreateInfoKHR(
      sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
      pNext: nil,
      flags: 0,
      surface: surface,
      minImageCount: capabilities.minImageCount + 1,
      imageFormat: surfaceFormat.format,
      imageColorSpace: surfaceFormat.colorSpace,
      imageExtent: capabilities.maxImageExtent,
      imageArrayLayers: 1,
      imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue,
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

    /*self.swapchain = try Swapchain.create(
      inDevice: device,
      createInfo: SwapchainCreateInfo(
        flags: .none,
        surface: surface,
        minImageCount: capabilities.minImageCount + 1,
        imageFormat: surfaceFormat.format,
        imageColorSpace: surfaceFormat.colorSpace,
        imageExtent: capabilities.maxImageExtent,
        imageArrayLayers: 1,
        imageUsage: .colorAttachment,
        imageSharingMode: .exclusive,
        queueFamilyIndices: [],
        preTransform: capabilities.currentTransform,
        compositeAlpha: compositeAlpha,
        presentMode: .immediate,
        clipped: true,
        oldSwapchain: nil
      ))
      self.swapchainImageFormat = surfaceFormat.format
      self.swapchainExtent = capabilities.minImageExtent

    self.swapchainImages = try self.swapchain.getSwapchainImages()*/
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

  func getSwapchainImages() {

  }
}

/*
public class VulkanRenderer {
  @Deferred var window: Window
  @Deferred var windowSurface: VLKWindowSurface
  @Deferred var instance: Instance
  @Deferred var surface: SurfaceKHR
  @Deferred var physicalDevice: PhysicalDevice
  @Deferred var queueFamilyIndex: UInt32
  @Deferred var device: Device
  @Deferred var queue: Queue
  @Deferred var swapchain: Swapchain
  @Deferred var swapchainImageFormat: Format
  @Deferred var swapchainExtent: Extent2D
  @Deferred var swapchainImages: [Image]
  @Deferred var imageViews: [ImageView]
  @Deferred var renderPass: RenderPass
  @Deferred var graphicsPipeline: Pipeline
  @Deferred var descriptorSetLayout: DescriptorSetLayout
  @Deferred var pipelineLayout: PipelineLayout
  @Deferred var framebuffers: [Framebuffer]
  @Deferred var commandPool: CommandPool
  @Deferred var depthImage: Image
  @Deferred var depthImageMemory: DeviceMemory
  @Deferred var depthImageView: ImageView

  var currentVertexBufferSize: DeviceSize = 0
  @Deferred var vertexBuffer: Buffer
  @Deferred var vertexBufferMemory: DeviceMemory
  @Deferred var vertexStagingBuffer: Buffer
  @Deferred var vertexStagingBufferMemory: DeviceMemory
  var vertexStagingBufferMemoryPointer: UnsafeMutableRawPointer?

  var currentIndexBufferSize: DeviceSize = 0
  @Deferred var indexBuffer: Buffer
  @Deferred var indexBufferMemory: DeviceMemory
  @Deferred var indexStagingBuffer: Buffer
  @Deferred var indexStagingBufferMemory: DeviceMemory
  var indexStagingBufferMemoryPointer: UnsafeMutableRawPointer?

  @Deferred var sceneDrawingManager: SceneDrawingManager

  @Deferred var uniformBuffers: [Buffer]
  @Deferred var uniformBuffersMemory: [DeviceMemory]
  @Deferred var mainMaterial: Material
  @Deferred var materialSystem: MaterialSystem
  @Deferred var descriptorPool: DescriptorPool
  @Deferred var descriptorSets: [DescriptorSet]
  @Deferred var imageAvailableSemaphores: [Vulkan.Semaphore]
  @Deferred var renderFinishedSemaphores: [Vulkan.Semaphore]
  @Deferred var inFlightFences: [Fence]
  var usedCommandBuffers: [Int: CommandBuffer] = [:]

  private var activeOneTimeCommandBuffers: [(CommandBuffer, Fence)] = []

  //let planeMesh = PlaneMesh()
  //let cubeMesh = CubeMesh()
  //let objMesh = ObjMesh(fileUrl: Bundle.module.url(forResource: "viking_room", withExtension: "obj")!)

  var camera = Camera(position: FVec3([0.01, 0.01, 0.01]))

  /*var vertices: [Vertex] = [][
    Vertex(position: Position3(x: -0.5, y: 0.5, z: 0.5), color: Color(r: 1, g: 0, b: 0), texCoord: Position2(x: 1, y: 0)),
    Vertex(position: Position3(x: 0.5, y: 0.5, z: 0.5), color: Color(r: 1, g: 0, b: 0), texCoord: Position2(x: 0, y: 0)),
    Vertex(position: Position3(x: 0.5, y: -0.5, z: 0.5), color: Color(r: 1, g: 0, b: 0), texCoord: Position2(x: 0, y: 1)),
    Vertex(position: Position3(x: -0.5, y: -0.5, z: 0.5), color: Color(r: 1, g: 0, b: 0), texCoord: Position2(x: 1, y: 1)),

    Vertex(position: Position3(x: -0.2, y: 0.8, z: 0.4), color: Color(r: 0, g: 0, b: 1), texCoord: Position2(x: 1, y: 0)),
    Vertex(position: Position3(x: 0.8, y: 0.8, z: 0.4), color: Color(r: 0, g: 0, b: 1), texCoord: Position2(x: 0, y: 0)),
    Vertex(position: Position3(x: 0.8, y: -0.2, z: 0.4), color: Color(r: 0, g: 0, b: 1), texCoord: Position2(x: 0, y: 1)),
    Vertex(position: Position3(x: -0.2, y: -0.2, z: 0.4), color: Color(r: 0, g: 0, b: 1), texCoord: Position2(x: 1, y: 1)),
  ]*/

  /*var indices: [UInt32] = [][
    4, 5, 6, 4, 6, 7,
    0, 1, 2, 0, 2, 3,
  ]*/

  let maxFramesInFlight = 2
  var currentFrameIndex = 0
  var imagesInFlightWithFences: [UInt32: Fence] = [:]

  public init(window: Window) throws {
    self.window = window

    self.windowSurface = window.surface as! VLKWindowSurface

    self.instance = Instance(pointer: windowSurface.instance)

    self.surface = SurfaceKHR(instance: instance, pointer: windowSurface.surface)

    /*try self.createInstance()

    try self.createSurface()*/

    try self.pickPhysicalDevice()

    try self.getQueueFamilyIndex()

    try self.createDevice()

    self.queue = Queue.create(fromDevice: self.device, presentFamilyIndex: queueFamilyIndex)

    try self.createSwapchain()

    try self.createImageViews()

    try self.createRenderPass()

    self.materialSystem = try MaterialSystem(vulkanRenderer: self)

    try self.createDescriptorSetLayout()

    try self.createGraphicsPipeline()

    try self.createCommandPool()

    try self.createDepthResources()

    try self.createFramebuffers()

    let initialVertexBufferSize = DeviceSize(48)
    try self.createVertexBuffer(size: initialVertexBufferSize)
    try self.createVertexStagingBuffer(size: initialVertexBufferSize)

    let initialIndexBufferSize = DeviceSize(4)
    try self.createIndexBuffer(size: initialIndexBufferSize)
    try self.createIndexStagingBuffer(size: initialIndexBufferSize)

    self.sceneDrawingManager = try SceneDrawingManager(vulkanRenderer: self)

    try self.createUniformBuffers()

    self.mainMaterial = try Material.load(textureUrl: Bundle.module.url(forResource: "viking_room", withExtension: "png")!)
    try self.materialSystem.buildForMaterial(self.mainMaterial)

    try self.createDescriptorPool()

    try self.createDescriptorSets()

    try self.createSyncObjects()
  }

  /*func createInstance() throws {
    let sdlExtensions = try! window.getVulkanInstanceExtensions()

    let createInfo = InstanceCreateInfo(
      applicationInfo: nil,
      enabledLayerNames: ["VK_LAYER_KHRONOS_validation"],
      enabledExtensionNames: sdlExtensions
    )

    self.instance = try Instance.createInstance(createInfo: createInfo)
  }

  func createSurface() throws {
    let drawingSurface = window.getVulkanDrawingSurface(instance: instance)
    self.surface = drawingSurface.vulkanSurface
  }*/

  func pickPhysicalDevice() throws {
    let devices = try instance.enumeratePhysicalDevices()
    self.physicalDevice = devices[0]
  }

  func getQueueFamilyIndex() throws {
    var queueFamilyIndex: UInt32?
    for properties in physicalDevice.queueFamilyProperties {
      if try! physicalDevice.hasSurfaceSupport(
        for: properties,
        surface:
          surface
      ) && properties.queueCount & QueueFamilyProperties.Flags.graphicsBit.rawValue == QueueFamilyProperties.Flags.graphicsBit.rawValue {
        queueFamilyIndex = properties.index
      }
    }

    guard let queueFamilyIndexUnwrapped = queueFamilyIndex else {
      throw VulkanRendererError.noSuitableQueueFamily
    }

    self.queueFamilyIndex = queueFamilyIndexUnwrapped
  }

  func createDevice() throws {
    let queueCreateInfo = DeviceQueueCreateInfo(
      flags: .none, queueFamilyIndex: queueFamilyIndex, queuePriorities: [1.0])

    var physicalDeviceFeatures = PhysicalDeviceFeatures()
    physicalDeviceFeatures.samplerAnisotropy = true

    self.device = try physicalDevice.createDevice(
      createInfo: DeviceCreateInfo(
        flags: .none,
        queueCreateInfos: [queueCreateInfo],
        enabledLayers: [],
        enabledExtensions: ["VK_KHR_swapchain"],
        enabledFeatures: physicalDeviceFeatures))
  }

  func createSwapchain() throws {
    let capabilities = try physicalDevice.getSurfaceCapabilities(surface: surface)
    let surfaceFormat = try selectFormat(for: physicalDevice, surface: surface)

    // Find a supported composite alpha mode - one of these is guaranteed to be set
    var compositeAlpha: CompositeAlphaFlags = .opaque
    let desiredCompositeAlpha =
      [compositeAlpha, .preMultiplied, .postMultiplied, .inherit]

    for desired in desiredCompositeAlpha {
      if capabilities.supportedCompositeAlpha.contains(desired) {
        compositeAlpha = desired
        break
      }
    }

    self.swapchain = try Swapchain.create(
      inDevice: device,
      createInfo: SwapchainCreateInfo(
        flags: .none,
        surface: surface,
        minImageCount: capabilities.minImageCount + 1,
        imageFormat: surfaceFormat.format,
        imageColorSpace: surfaceFormat.colorSpace,
        imageExtent: capabilities.maxImageExtent,
        imageArrayLayers: 1,
        imageUsage: .colorAttachment,
        imageSharingMode: .exclusive,
        queueFamilyIndices: [],
        preTransform: capabilities.currentTransform,
        compositeAlpha: compositeAlpha,
        presentMode: .immediate,
        clipped: true,
        oldSwapchain: nil
      ))
      self.swapchainImageFormat = surfaceFormat.format
      self.swapchainExtent = capabilities.minImageExtent

    self.swapchainImages = try self.swapchain.getSwapchainImages()
  }

  func selectFormat(for gpu: PhysicalDevice, surface: SurfaceKHR) throws -> SurfaceFormat {
    let formats = try gpu.getSurfaceFormats(for: surface)

    for format in formats {
      if format.format == .B8G8R8A8_SRGB {
        return format
      }
    }

    return formats[0]
  }

  func createImageView(image: Image, format: Format, aspectFlags: ImageAspectFlags) throws -> ImageView {
    try ImageView.create(device: device, createInfo: ImageViewCreateInfo(
      flags: .none,
      image: image,
      viewType: .type2D,
      format: format,
      components: ComponentMapping.identity,
      subresourceRange: ImageSubresourceRange(
        aspectMask: aspectFlags,
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1
      )
    ))
  }

  func createImageViews() throws {
    self.imageViews = try swapchainImages.map {
      try createImageView(image: $0, format: swapchainImageFormat, aspectFlags: .color)
    }
  }

  func createRenderPass() throws {
    let colorAttachment = AttachmentDescription(
      flags: .none,
      format: swapchainImageFormat,
      samples: ._1bit,
      loadOp: .clear,
      storeOp: .store,
      stencilLoadOp: .dontCare,
      stencilStoreOp: .dontCare,
      initialLayout: .undefined,
      finalLayout: .presentSrc 
    )

    let colorAttachmentRef = AttachmentReference(
      attachment: 0, layout: .colorAttachmentOptimal 
    )

    let depthAttachment = AttachmentDescription(
      flags: .none,
      // maybe should choose this with function as well (like for createDepthImage)
      format: .D32_SFLOAT, 
      samples: ._1bit,
      loadOp: .clear,
      storeOp: .dontCare,
      stencilLoadOp: .dontCare,
      stencilStoreOp: .dontCare,
      initialLayout: .undefined,
      finalLayout: .depthStencilAttachmentOptimal
    )

    let depthAttachmentRef = AttachmentReference(
      attachment: 1,
      layout: .depthStencilAttachmentOptimal
    )

    let subpass = SubpassDescription(
      flags: .none,
      pipelineBindPoint: .graphics,
      inputAttachments: nil,
      colorAttachments: [colorAttachmentRef],
      resolveAttachments: nil,
      depthStencilAttachment: depthAttachmentRef,
      preserveAttachments: nil
    )

    let dependency = SubpassDependency(
      srcSubpass: VK_SUBPASS_EXTERNAL,
      dstSubpass: 0,
      srcStageMask: [.colorAttachmentOutput, .earlyFragmentTests],
      dstStageMask: [.colorAttachmentOutput, .earlyFragmentTests],
      srcAccessMask: [],
      dstAccessMask: [.colorAttachmentWrite, .depthStencilAttachmentWrite],
      dependencyFlags: .none
    )

    let renderPassInfo = RenderPassCreateInfo(
      flags: .none,
      attachments: [colorAttachment, depthAttachment],
      subpasses: [subpass],
      dependencies: [dependency]
    )

    self.renderPass = try RenderPass.create(createInfo: renderPassInfo, device: device)
  }

  func createDescriptorSetLayout() throws {
    let uboLayoutBinding = DescriptorSetLayoutBinding(
      binding: 0,
      descriptorType: .uniformBuffer,
      descriptorCount: 1,
      stageFlags: .vertex,
      immutableSamplers: nil
    )

    /*let samplerLayoutBinding = DescriptorSetLayoutBinding(
      binding: 1,
      descriptorType: .combinedImageSampler,
      descriptorCount: 1,
      stageFlags: .fragment,
      immutableSamplers: nil
    )*/

    descriptorSetLayout = try DescriptorSetLayout.create(device: device, createInfo: DescriptorSetLayoutCreateInfo(
      flags: .none, bindings: [uboLayoutBinding, /*samplerLayoutBinding*/]
    ))
  }

  func createGraphicsPipeline() throws {
    let vertexShaderCode: Data = try Data(contentsOf: Bundle.module.url(forResource: "vertex", withExtension: "spv")!)
    let fragmentShaderCode: Data = try Data(contentsOf: Bundle.module.url(forResource: "fragment", withExtension: "spv")!)

    let vertexShaderModule = try ShaderModule(device: device, createInfo: ShaderModuleCreateInfo(
      code: vertexShaderCode
    ))
    let vertexShaderStageCreateInfo = PipelineShaderStageCreateInfo(
      flags: .none,
      stage: .vertex,
      module: vertexShaderModule,
      pName: "main",
      specializationInfo: nil)

    let fragmentShaderModule = try ShaderModule(device: device, createInfo: ShaderModuleCreateInfo(
      code: fragmentShaderCode
    ))
    let fragmentShaderStageCreateInfo = PipelineShaderStageCreateInfo(
      flags: .none,
      stage: .fragment,
      module: fragmentShaderModule,
      pName: "main",
      specializationInfo: nil)

    let shaderStages = [vertexShaderStageCreateInfo, fragmentShaderStageCreateInfo]

    let vertexInputBindingDescription = Vertex.inputBindingDescription
    let vertexInputAttributeDescriptions = Vertex.inputAttributeDescriptions

    let vertexInputInfo = PipelineVertexInputStateCreateInfo(
      vertexBindingDescriptions: [vertexInputBindingDescription],
      vertexAttributeDescriptions: vertexInputAttributeDescriptions
    )

    let inputAssembly = PipelineInputAssemblyStateCreateInfo(topology: .triangleList, primitiveRestartEnable: false)

    let viewport = Viewport(x: 0, y: 0, width: Float(swapchainExtent.width), height: Float(swapchainExtent.height), minDepth: 0, maxDepth: 1)

    let scissor = Rect2D(offset: Offset2D(x: 0, y: 0), extent: swapchainExtent)

    let viewportState = PipelineViewportStateCreateInfo(
      viewports: [viewport],
      scissors: [scissor]
    )

    let rasterizer = PipelineRasterizationStateCreateInfo(
      depthClampEnable: false,
      rasterizerDiscardEnable: false,
      polygonMode: .fill,
      cullMode: .none,
      frontFace: .clockwise,
      depthBiasEnable: false,
      depthBiasConstantFactor: 0,
      depthBiasClamp: 0,
      depthBiasSlopeFactor: 0,
      lineWidth: 1
    )

    let multisampling = PipelineMultisampleStateCreateInfo(
      rasterizationSamples: ._1,
      sampleShadingEnable: false,
      minSampleShading: 1,
      sampleMask: nil, 
      alphaToCoverageEnable: false,
      alphaToOneEnable: false
    )

    let colorBlendAttachment = PipelineColorBlendAttachmentState(
      blendEnable: true,
      srcColorBlendFactor: .srcAlpha,
      dstColorBlendFactor: .oneMinusSrcAlpha,
      colorBlendOp: .add,
      srcAlphaBlendFactor: .srcAlpha,
      dstAlphaBlendFactor: .oneMinusSrcAlpha,
      alphaBlendOp: .add,
      colorWriteMask: [.r, .g, .b, .a]
    )

    let colorBlending = PipelineColorBlendStateCreateInfo(
      logicOpEnable: false,
      logicOp: .copy,
      attachments: [colorBlendAttachment],
      blendConstants: (0, 0, 0, 0)
    )

    let dynamicStates = [DynamicState.viewport, DynamicState.lineWidth]

    let dynamicState = PipelineDynamicStateCreateInfo(
      dynamicStates: dynamicStates
    )

    let pushConstantRange = PushConstantRange(
      stageFlags: .vertex,
      offset: 0,
      size: UInt32(MemoryLayout<Float>.size * 17)
    )

    let pipelineLayoutInfo = PipelineLayoutCreateInfo(
      flags: .none,
      setLayouts: [descriptorSetLayout, materialSystem.descriptorSetLayout],
      pushConstantRanges: [pushConstantRange])

    let pipelineLayout = try PipelineLayout.create(device: device, createInfo: pipelineLayoutInfo)

    let pipelineInfo = GraphicsPipelineCreateInfo(
      flags: [],
      stages: shaderStages,
      vertexInputState: vertexInputInfo,
      inputAssemblyState: inputAssembly,
      tessellationState: nil,
      viewportState: viewportState,
      rasterizationState: rasterizer,
      multisampleState: multisampling,
      depthStencilState: PipelineDepthStencilStateCreateInfo(
        depthTestEnable: true,
        depthWriteEnable: true,
        depthCompareOp: .less,
        depthBoundsTestEnable: false,
        stencilTestEnable: false,
        front: .dontCare,
        back: .dontCare, 
        minDepthBounds: 0,
        maxDepthBounds: 1
      ),
      colorBlendState: colorBlending,
      dynamicState: nil,
      layout: pipelineLayout,
      renderPass: renderPass,
      subpass: 0,
      basePipelineHandle: nil,
      basePipelineIndex: 0 
    )

    let graphicsPipeline = try Pipeline(device: device, createInfo: pipelineInfo)

    self.graphicsPipeline = graphicsPipeline
    self.pipelineLayout = pipelineLayout
  }

  func createFramebuffers() throws {
    self.framebuffers = try imageViews.map { imageView in
      let framebufferInfo = FramebufferCreateInfo(
        flags: [],
        renderPass: renderPass,
        attachments: [imageView, depthImageView],
        width: swapchainExtent.width,
        height: swapchainExtent.height,
        layers: 1 
      )
      return try Framebuffer(device: device, createInfo: framebufferInfo)
    }
  }

  func createCommandPool() throws {
    self.commandPool = try CommandPool.create(from: device, info: CommandPoolCreateInfo(
      flags: .none,
      queueFamilyIndex: queueFamilyIndex
    ))
  }

  func createBuffer(size: DeviceSize, usage: BufferUsageFlags, properties: MemoryPropertyFlags) throws -> (Buffer, DeviceMemory) {
    let bufferInfo = BufferCreateInfo(
      flags: .none,
      size: size,
      usage: usage,
      sharingMode: .exclusive,
      queueFamilyIndices: nil)
    let buffer = try Buffer.create(device: device, createInfo: bufferInfo)

    let memRequirements = buffer.memoryRequirements

    let bufferMemory = try DeviceMemory.allocateMemory(inDevice: device, allocInfo: MemoryAllocateInfo(
      allocationSize: memRequirements.size,
      memoryTypeIndex: try findMemoryType(typeFilter: memRequirements.memoryTypeBits, properties: properties.rawValue)
    ))

    try buffer.bindMemory(memory: bufferMemory)

    return (buffer, bufferMemory)
  }

  func findMemoryType(typeFilter: UInt32, properties: UInt32) throws -> UInt32 {
    let memProperties = try physicalDevice.getMemoryProperties()
    for (index, checkType) in memProperties.memoryTypes.enumerated() {
      if typeFilter & (1 << index) != 0 && checkType.propertyFlags.rawValue & properties == properties {
        return UInt32(index)
      }
    }

    throw VulkanRendererError.noSuitableMemoryType 
  }

  func beginSingleTimeCommands() throws -> CommandBuffer {
    let commandBuffer = try CommandBuffer.allocate(device: device, info: CommandBufferAllocateInfo(
      commandPool: commandPool,
      level: .primary,
      commandBufferCount: 1
    ))
    commandBuffer.begin(CommandBufferBeginInfo(
      flags: .oneTimeSubmit, inheritanceInfo: nil
    ))

    return commandBuffer
  }

  func endSingleTimeCommands(commandBuffer: CommandBuffer) throws {
    let fence = try Fence(device: device, createInfo: FenceCreateInfo(flags: []))
    commandBuffer.end()

    try queue.submit(submits: [SubmitInfo(
      waitSemaphores: [],
      waitDstStageMask: nil,
      commandBuffers: [commandBuffer],
      signalSemaphores: []
    )], fence: fence)

    activeOneTimeCommandBuffers.append((commandBuffer, fence))
  }

  func copyBuffer(srcBuffer: Buffer, dstBuffer: Buffer, size: DeviceSize, srcOffset: DeviceSize = 0, dstOffset: DeviceSize = 0) throws {
    let commandBuffer = try beginSingleTimeCommands()
    commandBuffer.copyBuffer(srcBuffer: srcBuffer, dstBuffer: dstBuffer, regions: [BufferCopy(
      srcOffset: srcOffset, dstOffset: dstOffset, size: size 
    )])
    try endSingleTimeCommands(commandBuffer: commandBuffer)
  }

  func createImage(
    width: UInt32,
    height: UInt32,
    format: Format,
    tiling: ImageTiling,
    usage: ImageUsageFlags,
    properties: MemoryPropertyFlags) throws -> (Image, DeviceMemory) {
      let image = try Image.create(withInfo: ImageCreateInfo(
        flags: .none,
        imageType: .type2D,
        format: format,
        extent: Extent3D(width: width, height: height, depth: 1),
        mipLevels: 1,
        arrayLayers: 1,
        samples: ._1bit,
        tiling: tiling,
        usage: usage,
        sharingMode: .exclusive,
        queueFamilyIndices: nil,
        initialLayout: .undefined
      ), device: device)

      let memRequirements = image.memoryRequirements

      let memory = try DeviceMemory.allocateMemory(inDevice: device, allocInfo: MemoryAllocateInfo(
        allocationSize: memRequirements.size,
        memoryTypeIndex: try findMemoryType(typeFilter: memRequirements.memoryTypeBits, properties: MemoryPropertyFlags.deviceLocal.rawValue)
      ))

      try image.bindMemory(memory: memory)

      return (image, memory)
  }

  func transitionImageLayout(image: Image, format: Format, oldLayout: ImageLayout, newLayout: ImageLayout) throws {
    let commandBuffer = try beginSingleTimeCommands()

    var barrier = ImageMemoryBarrier(
      srcAccessMask: [],
      dstAccessMask: [],
      oldLayout: oldLayout,
      newLayout: newLayout,
      srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
      dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
      image: image,
      subresourceRange: ImageSubresourceRange(
        aspectMask: .color,
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1
      ))
    
    let sourceStage: PipelineStageFlags
    let destinationStage: PipelineStageFlags

    if oldLayout == .undefined && newLayout == .transferDstOptimal {
      barrier.srcAccessMask = []
      barrier.dstAccessMask = .transferWrite

      sourceStage = .topOfPipe
      destinationStage = .transfer
    } else if oldLayout == .transferDstOptimal && newLayout == .shaderReadOnlyOptimal {
      barrier.srcAccessMask = .transferWrite
      barrier.dstAccessMask = .shaderRead

      sourceStage = .transfer
      destinationStage = .fragmentShader
    } else {
      throw VulkanRendererError.unsupportedImageLayoutTransition(old: oldLayout, new: newLayout)
    }

    commandBuffer.pipelineBarrier(
      srcStageMask: sourceStage, 
      dstStageMask: destinationStage, 
      dependencyFlags: [],
      memoryBarriers: [],
      bufferMemoryBarriers: [],
      imageMemoryBarriers: [barrier]
    )

    try endSingleTimeCommands(commandBuffer: commandBuffer)
  }

  func copyBufferToImage(buffer: Buffer, image: Image, width: UInt32, height: UInt32) throws {
    let commandBuffer = try beginSingleTimeCommands()

    let region = BufferImageCopy(
      bufferOffset: 0,
      bufferRowLength: 0,
      bufferImageHeight: 0,
      imageSubresource: ImageSubresourceLayers(
        aspectMask: .color,
        mipLevel: 0,
        baseArrayLayer: 0,
        layerCount: 1
      ),
      imageOffset: Offset3D(x: 0, y: 0, z: 0),
      imageExtent: Extent3D(width: width, height: height, depth: 1)
    )
    commandBuffer.copyBufferToImage(srcBuffer: buffer, dstImage: image, dstImageLayout: .transferDstOptimal, regions: [region])

    try endSingleTimeCommands(commandBuffer: commandBuffer)
  }

  func createDepthResources() throws {
    // TODO: probably depthFormat should be chosen according to support,
    // as shown in tutorial
    let depthFormat = Format.D32_SFLOAT

    (depthImage, depthImageMemory) = try createImage(
      width: swapchainExtent.width,
      height: swapchainExtent.height,
      format: depthFormat,
      tiling: .optimal,
      usage: .depthStencilAttachment,
      properties: .deviceLocal)

    depthImageView = try createImageView(image: depthImage, format: depthFormat, aspectFlags: .depth)
  }

  /*func createTextureImage() throws {
    //let image = try CpuImage(contentsOf: Bundle.module.url(forResource: "viking_room", withExtension: "png")!)
    let imageWidth = guiSurface.size.width
    let imageHeight = guiSurface.size.height
    let channelCount = 4 
    //let imageDataSize = imageWidth * imageHeight * channelCount
    let dataSize = Int(guiSurface.size.width * guiSurface.size.height * 4)

    //let skiaDrawnDataPointer = testDraw(Int32(imageWidth), Int32(imageHeight))
    //let image = CpuImage(width: 200, height: 200, rgba: Array(repeating: 255, count: imageDataSize))

    let (stagingBuffer, stagingBufferMemory) = try createBuffer(
      size: DeviceSize(dataSize), usage: [.transferSrc], properties: [.hostVisible, .hostCoherent])
    
    var dataPointer: UnsafeMutableRawPointer? = nil
    try stagingBufferMemory.mapMemory(offset: 0, size: DeviceSize(dataSize), flags: .none, data: &dataPointer)
    dataPointer?.copyMemory(from: guiSurface.buffer, byteCount: dataSize)
    stagingBufferMemory.unmapMemory()

    (textureImage, textureImageMemory) = try createImage(
      width: UInt32(imageWidth),
      height: UInt32(imageHeight),
      format: .R8G8B8A8_SRGB /* note */,
      tiling: .optimal,
      usage: [.transferDst, .sampled],
      properties: [.hostVisible, .hostCoherent])

    try transitionImageLayout(image: textureImage, format: .R8G8B8A8_SRGB /* note */, oldLayout: .undefined, newLayout: .transferDstOptimal)

    try copyBufferToImage(buffer: stagingBuffer, image: textureImage, width: UInt32(imageWidth), height: UInt32(imageHeight))

    try transitionImageLayout(image: textureImage, format: .R8G8B8A8_SRGB /* note */, oldLayout: .transferDstOptimal, newLayout: .shaderReadOnlyOptimal)
  }

  func createTextureImageView() throws {
    textureImageView = try createImageView(image: textureImage, format: .R8G8B8A8_SRGB /* note */, aspectFlags: .color)
  }

  func createTextureSampler() throws {
    textureSampler = try Sampler(device: device, createInfo: SamplerCreateInfo(
      magFilter: .linear,
      minFilter: .linear,
      mipmapMode: .linear,
      addressModeU: .repeat,
      addressModeV: .repeat,
      addressModeW: .repeat,
      mipLodBias: 0,
      anisotropyEnable: true,
      maxAnisotropy: physicalDevice.properties.limits.maxSamplerAnisotropy,
      compareEnable: false,
      compareOp: .always,
      minLod: 0,
      maxLod: 0,
      borderColor: .intOpaqueBlack,
      unnormalizedCoordinates: false
    ))
  }*/

  func createVertexBuffer(size: DeviceSize) throws {
    _vertexBuffer.value?.destroy()
    _vertexBufferMemory.value?.free()
    _vertexBufferMemory.value?.destroy()
    (vertexBuffer, vertexBufferMemory) = try createBuffer(
      size: size,
      usage: [.vertexBuffer, .transferDst],
      properties: [.hostVisible, .hostCoherent])
    self.currentVertexBufferSize = size
  }

  func createVertexStagingBuffer(size: DeviceSize) throws {
    _vertexStagingBuffer.value?.destroy()
    _vertexStagingBufferMemory.value?.unmapMemory()
    _vertexStagingBufferMemory.value?.free()
    _vertexStagingBufferMemory.value?.destroy()
    (vertexStagingBuffer, vertexStagingBufferMemory) = try createBuffer(
      size: size,
      usage: .transferSrc,
      properties: [.hostVisible, .hostCoherent])
    try vertexStagingBufferMemory.mapMemory(offset: 0, size: size, flags: .none, data: &vertexStagingBufferMemoryPointer)
  }

  func transferVertices(vertices: [Vertex]) throws {
    let vertexData = vertices.flatMap { $0.serializedData }
    let dataSize = DeviceSize(MemoryLayout<Float>.size * vertexData.count)

    if dataSize > currentVertexBufferSize {
      let newSize = max(currentVertexBufferSize * 2, dataSize)
      try createVertexBuffer(size: newSize)
      try createVertexStagingBuffer(size: newSize)
      print("recreated vertex buffer with double size because ran out of memory")
    }

    vertexStagingBufferMemoryPointer?.copyMemory(from: vertexData, byteCount: MemoryLayout<Float>.size * vertexData.count)
    try copyBuffer(srcBuffer: vertexStagingBuffer, dstBuffer: vertexBuffer, size: dataSize)
  }

  func createIndexBuffer(size: DeviceSize) throws {
    _indexBuffer.value?.destroy()
    _indexBufferMemory.value?.free()
    _indexBufferMemory.value?.destroy()
    if (_indexBuffer.value != nil && _indexBufferMemory.value != nil) {
      print("HERE", indexBuffer)
      indexBuffer.destroy()
      print("HERE")
    }
    (indexBuffer, indexBufferMemory) = try createBuffer(size: size, usage: [.transferDst, .indexBuffer], properties: [.deviceLocal])
    self.currentIndexBufferSize = size
  }

  func createIndexStagingBuffer(size: DeviceSize) throws {
    _indexStagingBuffer.value?.destroy()
    _indexStagingBufferMemory.value?.unmapMemory()
    _indexStagingBufferMemory.value?.free()
    _indexStagingBufferMemory.value?.destroy()
    (indexStagingBuffer, indexStagingBufferMemory) = try createBuffer(size: size, usage: .transferSrc, properties: [.hostVisible, .hostCoherent])
    try indexStagingBufferMemory.mapMemory(offset: 0, size: size, flags: .none, data: &indexStagingBufferMemoryPointer)
  }

  func transferVertexIndices(indices: [UInt32]) throws {
    let dataSize = DeviceSize(MemoryLayout.size(ofValue: indices[0]) * indices.count)

    if dataSize > currentIndexBufferSize {
      let newSize = max(currentIndexBufferSize * 2, dataSize)
      try createIndexBuffer(size: newSize)
      try createIndexStagingBuffer(size: newSize)
      print("recreated index buffer with double size because ran out of memory")
    }

    indexStagingBufferMemoryPointer?.copyMemory(from: indices, byteCount: Int(dataSize))

    try copyBuffer(srcBuffer: indexStagingBuffer, dstBuffer: indexBuffer, size: dataSize)
  }

  func createUniformBuffers() throws {
    let bufferSize = DeviceSize(UniformBufferObject.dataSize)

    uniformBuffers = []
    uniformBuffersMemory = []
    
    for _ in 0..<swapchainImages.count {
      let (buffer, bufferMemory) = try createBuffer(size: bufferSize, usage: .uniformBuffer, properties: [.hostVisible, .hostCoherent])
      uniformBuffers.append(buffer)
      uniformBuffersMemory.append(bufferMemory)
    }
  }

  func createDescriptorPool() throws {
    descriptorPool = try DescriptorPool.create(device: device, createInfo: DescriptorPoolCreateInfo(
      flags: .none,
      maxSets: UInt32(swapchainImages.count),
      poolSizes: [
        DescriptorPoolSize(
          type: .uniformBuffer, descriptorCount: UInt32(swapchainImages.count)
        ),
        DescriptorPoolSize(
          type: .combinedImageSampler, descriptorCount: UInt32(swapchainImages.count)
        )
      ]
    ))
  }

  func createDescriptorSets() throws {
    descriptorSets = DescriptorSet.allocate(device: device, allocateInfo: DescriptorSetAllocateInfo(
        descriptorPool: descriptorPool,
        descriptorSetCount: UInt32(swapchainImages.count),
        setLayouts: Array(repeating: descriptorSetLayout, count: swapchainImages.count)))
    
    for i in 0..<swapchainImages.count {
      let bufferInfo = DescriptorBufferInfo(
        buffer: uniformBuffers[i], offset: 0, range: DeviceSize(UniformBufferObject.dataSize)
      )

      /*let imageInfo = DescriptorImageInfo(
        sampler: textureSampler, imageView: textureImageView, imageLayout: .shaderReadOnlyOptimal 
      )*/

      let descriptorWrites = [
        WriteDescriptorSet(
          dstSet: descriptorSets[i],
          dstBinding: 0,
          dstArrayElement: 0,
          descriptorCount: 1,
          descriptorType: .uniformBuffer,
          imageInfo: [],
          bufferInfo: [bufferInfo],
          texelBufferView: []),
        /*WriteDescriptorSet(
          dstSet: descriptorSets[i],
          dstBinding: 1,
          dstArrayElement: 0,
          descriptorCount: 1,
          descriptorType: .combinedImageSampler,
          imageInfo: [imageInfo],
          bufferInfo: [],
          texelBufferView: [])*/
      ]

      device.updateDescriptorSets(descriptorWrites: descriptorWrites, descriptorCopies: nil)
    }
  }

  func createSyncObjects() throws {
    imageAvailableSemaphores = try (0..<maxFramesInFlight).map { _ in 
      try Vulkan.Semaphore.create(info: SemaphoreCreateInfo(
        flags: .none
      ), device: device)
    }

    renderFinishedSemaphores = try (0..<maxFramesInFlight).map { _ in 
      try Vulkan.Semaphore.create(info: SemaphoreCreateInfo(
        flags: .none
      ), device: device)
    }

    inFlightFences = try (0..<maxFramesInFlight).map { _ in
      try Fence(device: device, createInfo: FenceCreateInfo(
        flags: [.signaled]
      ))
    }
  }

  func drawFrame(gameObjects: [GameObject]) throws {
    try sceneDrawingManager.update(gameObjects: gameObjects)

    //let sceneDrawInfo = try generateSceneDrawInfo(gameObjects: gameObjects)
    /*try measureDuration("updateRenderBuffers") {
      try updateRenderBuffers(with: sceneDrawInfo)
    }*/

    let imageAvailableSemaphore = imageAvailableSemaphores[currentFrameIndex]
    let renderFinishedSemaphore = renderFinishedSemaphores[currentFrameIndex]
    let inFlightFence = inFlightFences[currentFrameIndex]

    inFlightFence.wait(timeout: .max)

    for destroy in materialSystem.currentFrameCompleteDestructorQueue {
      destroy()
    }
    materialSystem.currentFrameCompleteDestructorQueue = []

    let (imageIndex, acquireImageResult) = try swapchain.acquireNextImage(timeout: .max, semaphore: imageAvailableSemaphore, fence: nil)
    if let usedCommandBuffer = usedCommandBuffers[Int(imageIndex)] {
      CommandBuffer.free(commandBuffers: [usedCommandBuffer], device: device, commandPool: commandPool)
    }

    if acquireImageResult == .errorOutOfDateKhr {
      device.waitIdle()
      queue.waitIdle()
      cleanupSwapchain()
      try recreateSwapchain()
      return
    } else if acquireImageResult != .success && acquireImageResult != .suboptimalKhr {
      throw UnexpectedVulkanResultError(acquireImageResult)
    }

    if let previousFence = imagesInFlightWithFences[imageIndex] {
      //previousFence.wait(timeout: .max)
    }
    imagesInFlightWithFences[imageIndex] = inFlightFence
    inFlightFence.reset()

    let commandBuffer = try recordCommandBuffer(framebufferIndex: Int(imageIndex))

    try updateUniformBuffer(currentImage: imageIndex)

    try queue.submit(submits: [
      SubmitInfo(
        waitSemaphores: [imageAvailableSemaphore],
        waitDstStageMask: [.colorAttachmentOutput],
        commandBuffers: [commandBuffer],
        signalSemaphores: [renderFinishedSemaphore]
      )
    ], fence: inFlightFence)

    let presentResult = queue.present(presentInfo: PresentInfoKHR(
      waitSemaphores: [renderFinishedSemaphore],
      swapchains: [swapchain],
      imageIndices: [imageIndex],
      results: ()
    ))

    if presentResult == .errorOutOfDateKhr || presentResult == .suboptimalKhr {
      device.waitIdle()
      queue.waitIdle()
      cleanupSwapchain()
      try recreateSwapchain()
      return
    } else if presentResult != .success {
      throw UnexpectedVulkanResultError(acquireImageResult)
    }

    usedCommandBuffers[Int(imageIndex)] = commandBuffer

    testFreeSingleTimeCommandBuffers()

    currentFrameIndex += 1
    currentFrameIndex %= maxFramesInFlight
  }

  func generateSceneDrawInfo(gameObjects: [GameObject]) throws -> SceneDrawInfo {
    let sceneDrawInfo = SceneDrawInfo()

    for gameObject in gameObjects {
      if let meshGameObject = gameObject as? MeshGameObject {
        let newVertices: [Vertex] = meshGameObject.mesh.vertices/*meshGameObject.mesh.vertices.map {
          let transformedPosition = FVec3(Array(gameObject.transformation.matmul(FVec4($0.position.elements + [1])).elements[0..<3]))
          return Vertex(position: transformedPosition, color: $0.color, texCoord: $0.texCoord)
        }*/
        let newIndices = meshGameObject.mesh.indices.map {
          $0 + UInt32(sceneDrawInfo.vertices.count)
        }

        var materialRenderData = materialSystem.materialRenderData[ObjectIdentifier(mainMaterial)]!
        if let material = meshGameObject.mesh.material {
          try materialSystem.buildForMaterial(material)
          materialRenderData = materialSystem.materialRenderData[ObjectIdentifier(material)]!
        }
        
        sceneDrawInfo.meshDrawInfos.append(MeshDrawInfo(
          mesh: meshGameObject.mesh,
          materialRenderData: materialRenderData,
          transformation: meshGameObject.transformation,
          projectionEnabled: meshGameObject.projectionEnabled,
          indicesStartIndex: UInt32(sceneDrawInfo.indices.count),
          indicesCount: UInt32(newIndices.count)
        ))
        sceneDrawInfo.vertices.append(contentsOf: newVertices)
        sceneDrawInfo.indices.append(contentsOf: newIndices)
      }
    }

    return sceneDrawInfo
  }

  func updateRenderBuffers(with sceneDrawInfo: SceneDrawInfo) throws {
    try transferVertices(vertices: sceneDrawInfo.vertices)
    try transferVertexIndices(indices: sceneDrawInfo.indices)
  }

  func recordCommandBuffer(framebufferIndex: Int) throws -> CommandBuffer {
    let framebuffer = framebuffers[framebufferIndex]

    let commandBuffer = try CommandBuffer.allocate(device: device, info: CommandBufferAllocateInfo(
      commandPool: commandPool,
      level: .primary,
      commandBufferCount: 1))

    commandBuffer.begin(CommandBufferBeginInfo(
      flags: [],
      inheritanceInfo: nil))

    commandBuffer.beginRenderPass(beginInfo: RenderPassBeginInfo(
      renderPass: renderPass,
      framebuffer: framebuffer,
      renderArea: Rect2D(
        offset: Offset2D(x: 0, y: 0), extent: swapchainExtent
      ),
      clearValues: [
        ClearColorValue.float32(0, 0, 0, 1).eraseToAny(),
        ClearDepthStencilValue(depth: 1, stencil: 0).eraseToAny()]
    ), contents: .inline)

    commandBuffer.bindPipeline(pipelineBindPoint: .graphics, pipeline: graphicsPipeline)

    //commandBuffer.bindVertexBuffers(firstBinding: 0, buffers: [vertexBuffer], offsets: [0])
    //commandBuffer.bindIndexBuffer(buffer: indexBuffer, offset: 0, indexType: VK_INDEX_TYPE_UINT32)

    /*for meshDrawInfo in sceneDrawInfo.meshDrawInfos {
      var pushConstants = meshDrawInfo.transformation.transposed.elements
      pushConstants.append(meshDrawInfo.projectionEnabled ? 1 : 0)
      commandBuffer.pushConstants(layout: pipelineLayout, stageFlags: .vertex, offset: 0, size: UInt32(MemoryLayout<Float>.size * pushConstants.count), values: pushConstants)

      commandBuffer.bindDescriptorSets(
        pipelineBindPoint: .graphics,
        layout: pipelineLayout,
        firstSet: 0,
        descriptorSets: [descriptorSets[framebufferIndex], meshDrawInfo.materialRenderData.descriptorSets[framebufferIndex]],
        dynamicOffsets: [])

      commandBuffer.drawIndexed(indexCount: meshDrawInfo.indicesCount, instanceCount: 1, firstIndex: meshDrawInfo.indicesStartIndex, vertexOffset: 0, firstInstance: 0)
    }*/

    commandBuffer.bindVertexBuffers(firstBinding: 0, buffers: [sceneDrawingManager.sceneDrawInfo.vertexBuffer.buffer], offsets: [0])
    commandBuffer.bindIndexBuffer(buffer: sceneDrawingManager.sceneDrawInfo.indexBuffer.buffer, offset: 0, indexType: VK_INDEX_TYPE_UINT32)

    for gameObject in gameObjects {
      if let meshGameObject = gameObject as? MeshGameObject {
        let gameObjectDrawInfo = sceneDrawingManager.sceneDrawInfo.gameObjectDrawInfos[meshGameObject]!

        var pushConstants = gameObject.transformation.transposed.elements
        pushConstants.append(1)//gameObject.projectionEnabled ? 1 : 0)
        commandBuffer.pushConstants(layout: pipelineLayout, stageFlags: .vertex, offset: 0, size: UInt32(MemoryLayout<Float>.size * pushConstants.count), values: pushConstants)

        commandBuffer.bindDescriptorSets(
          pipelineBindPoint: .graphics,
          layout: pipelineLayout,
          firstSet: 0,
          descriptorSets: [descriptorSets[framebufferIndex], gameObjectDrawInfo.materialDrawData.descriptorSets[framebufferIndex]],
          dynamicOffsets: [])

        commandBuffer.drawIndexed(
          indexCount: UInt32(meshGameObject.mesh.indices.count),
          instanceCount: 1,
          firstIndex: UInt32(gameObjectDrawInfo.indicesStartIndex),
          vertexOffset: Int32(gameObjectDrawInfo.vertexOffset),
          firstInstance: 0)
      }
    }

    commandBuffer.endRenderPass()
    commandBuffer.end()

    return commandBuffer
  }

  func updateUniformBuffer(currentImage: UInt32) throws {
    /*var windowWidth: Int32 = 0
    var windowHeight: Int32 = 0
    SDL_GetWindowSize(window, &windowWidth, &windowHeight)*/
    let windowSurfaceSize = windowSurface.getDrawableSize()
    let aspectRatio = Float(windowSurfaceSize.width) / Float(windowSurfaceSize.height)

    let uniformBufferObject = UniformBufferObject(
      model: FMat4.identity/*newRotation(yaw: 0, pitch: 0)*/.matmul(FMat4([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
      ])),
      view: camera.viewMatrix.transposed,
      projection: FMat4.newProjection(
        aspectRatio: aspectRatio, fov: 90, near: 0.1, far: 100).transposed)

    var dataPointer: UnsafeMutableRawPointer? = nil
    try uniformBuffersMemory[Int(currentImage)].mapMemory(
      offset: 0,
      size: DeviceSize(UniformBufferObject.dataSize),
      flags: .none,
      data: &dataPointer)
    dataPointer?.copyMemory(from: uniformBufferObject.data, byteCount: UniformBufferObject.dataSize)
    uniformBuffersMemory[Int(currentImage)].unmapMemory()
  }

  func testFreeSingleTimeCommandBuffers() {
    activeOneTimeCommandBuffers.removeAll { (buffer, fence) in
      if fence.status == .success {
        CommandBuffer.free(commandBuffers: [buffer], device: device, commandPool: commandPool)
        return true
      }
      return false
    }
  }

  func recreateSwapchain() throws {
    let windowSurfaceSize = windowSurface.getDrawableSize()
    if windowSurfaceSize.width == 0 || windowSurfaceSize.height == 0 {
      return
    }
    /*var windowWidth: Int32 = 0
    var windowHeight: Int32 = 0
    SDL_GetWindowSize(window, &windowWidth, &windowHeight)
    var event = SDL_Event()
    while windowWidth == 0 || windowHeight == 0 {
      SDL_WaitEvent(&event)
      SDL_GetWindowSize(window, &windowWidth, &windowHeight)
    }*/

    device.waitIdle()

    try createSwapchain()
    try createImageViews()
    try createRenderPass()
    try createGraphicsPipeline()
    try createDepthResources()
    try createFramebuffers()
    try createUniformBuffers()
    try createDescriptorPool()
    try createDescriptorSets()
  }

  func cleanupSwapchain() {
    depthImageView.destroy()
    depthImage.destroy()
    depthImageMemory.destroy()
    framebuffers.forEach { $0.destroy() }
    graphicsPipeline.destroy()
    renderPass.destroy()
    imageViews.forEach { $0.destroy() }
    swapchain.destroy()

    for i in 0..<uniformBuffers.count {
      uniformBuffers[i].destroy()
      uniformBuffersMemory[i].free()
    }

    descriptorPool.destroy()
  }

  func destroy() {
    //vertexBuffer.destroy()
  }
} 

*/