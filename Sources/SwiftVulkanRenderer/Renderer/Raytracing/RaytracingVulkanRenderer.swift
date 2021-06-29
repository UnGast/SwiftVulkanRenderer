import Foundation
import Vulkan

public class RaytracingVulkanRenderer: VulkanRenderer {
  let scene: Scene
  let instance: VkInstance
  let surface: VkSurfaceKHR

  @Deferred public var physicalDevice: VkPhysicalDevice
  @Deferred var queueFamilyIndex: UInt32
  @Deferred public var device: VkDevice
  @Deferred public var queue: VkQueue
  @Deferred var swapchain: VkSwapchainKHR
  @Deferred var swapchainImageFormat: VkFormat
  @Deferred public var swapchainExtent: VkExtent2D
  @Deferred var swapchainImages: [VkImage]
  @Deferred var swapchainImageViews: [VkImageView]
  @Deferred var textureSampler: VkSampler

  @Deferred var descriptorPool: VkDescriptorPool
  @Deferred var framebufferDescriptorSetLayout: VkDescriptorSetLayout
  @Deferred var framebufferDescriptorSets: [VkDescriptorSet]
  @Deferred var sceneDescriptorSetLayout: VkDescriptorSetLayout
  @Deferred var sceneDescriptorSet: VkDescriptorSet

  @Deferred var computePipeline: VkPipeline
  @Deferred var computePipelineLayout: VkPipelineLayout
  @Deferred public var commandPool: VkCommandPool

  @Deferred var sceneManager: SceneManager
  
  var nextDrawSubmitWaits: [(VkSemaphore, VkPipelineStageFlags)] = []

  typealias CurrentDrawFinishSemaphoreCallback = () -> [VkSemaphore]
  var currentDrawFinishSemaphoreCallbacks = [CurrentDrawFinishSemaphoreCallback]()

  public init(scene: Scene, instance: VkInstance, surface: VkSurfaceKHR) throws {
    self.scene = scene
    self.instance = instance
    self.surface = surface

    try pickPhysicalDevice()

    try getQueueFamilyIndex()

    try createDevice()

    try createQueue()

    try createSwapchain()

    try getSwapchainImages()

    try createSwapchainImageViews()

    try createTextureSampler()

    sceneManager = try SceneManager(renderer: self)

    try createDescriptorPool()

    try createFramebufferDescriptorSetLayout()

    try createFramebufferDescriptorSets()

    try createSceneDescriptorSetLayout()

    try createSceneDescriptorSet()

    try createComputePipeline()

    try createCommandPool()
  }

  public func updateSceneContent() throws {
  }

	public func updateSceneObjectMeta() throws {
  }

  public func updateSceneCameraUniforms() throws {
  }

	func pickPhysicalDevice() throws {
    var deviceCount: UInt32 = 0
    vkEnumeratePhysicalDevices(instance, &deviceCount, nil)
    var devices = Array(repeating: Optional<VkPhysicalDevice>.none, count: Int(deviceCount))
    vkEnumeratePhysicalDevices(instance, &deviceCount, &devices)
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

    self.swapchainImageFormat = VK_FORMAT_B8G8R8A8_UNORM

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

  func getSwapchainImages() throws {
    var count: UInt32 = 0
    vkGetSwapchainImagesKHR(device, swapchain, &count, nil)
    var images = [VkImage?](repeating: VkImage(bitPattern: 0), count: Int(count))
    vkGetSwapchainImagesKHR(device, swapchain, &count, &images)
    self.swapchainImages = images.map { $0! }
  }

  func createSwapchainImageViews() throws {
    self.swapchainImageViews = try swapchainImages.map {
      try createImageView(image: $0, format: swapchainImageFormat, aspectFlags: VK_IMAGE_ASPECT_COLOR_BIT)
    }
  }

  func createTextureSampler() throws {
    var properties = VkPhysicalDeviceProperties()
    vkGetPhysicalDeviceProperties(physicalDevice, &properties)

    var samplerInfo = VkSamplerCreateInfo(
      sType: VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
      pNext: nil,
      flags: 0,
      magFilter: VK_FILTER_LINEAR,
      minFilter: VK_FILTER_LINEAR,
      mipmapMode: VK_SAMPLER_MIPMAP_MODE_LINEAR,
      addressModeU: VK_SAMPLER_ADDRESS_MODE_REPEAT,
      addressModeV: VK_SAMPLER_ADDRESS_MODE_REPEAT,
      addressModeW: VK_SAMPLER_ADDRESS_MODE_REPEAT,
      mipLodBias: 0,
      anisotropyEnable: 0,
      maxAnisotropy: properties.limits.maxSamplerAnisotropy,
      compareEnable: 0,
      compareOp: VK_COMPARE_OP_ALWAYS,
      minLod: 0,
      maxLod: 0,
      borderColor: VK_BORDER_COLOR_INT_OPAQUE_BLACK,
      unnormalizedCoordinates: 0
    )

    var textureSampler: VkSampler?
    vkCreateSampler(device, &samplerInfo, nil, &textureSampler)

    self.textureSampler = textureSampler!
  }

  func createDescriptorPool() throws {
    var poolSizes = [
      VkDescriptorPoolSize(
        type: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        descriptorCount: 1
      ),
      VkDescriptorPoolSize(
        type: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        descriptorCount: 2
      ),
      VkDescriptorPoolSize(
        type: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
        descriptorCount: 1024
      ),
      VkDescriptorPoolSize(
        type: VK_DESCRIPTOR_TYPE_SAMPLER,
        descriptorCount: 1
      ),
      VkDescriptorPoolSize(
        type: VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
        descriptorCount: UInt32(swapchainImages.count)
      )
    ]
    var createInfo = VkDescriptorPoolCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
      pNext: nil,
      flags: 0,
      maxSets: UInt32(swapchainImages.count) + 1,
      poolSizeCount: UInt32(poolSizes.count),
      pPoolSizes: &poolSizes
    )
    var descriptorPool: VkDescriptorPool? = nil

    vkCreateDescriptorPool(device, &createInfo, nil, &descriptorPool)

    self.descriptorPool = descriptorPool!
  }

  func createFramebufferDescriptorSetLayout() throws {
    var samplers = [Optional(textureSampler)]
    var bindings: [VkDescriptorSetLayoutBinding] = [
      VkDescriptorSetLayoutBinding(
        binding: 0,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
        descriptorCount: 1,
        stageFlags: VK_SHADER_STAGE_COMPUTE_BIT.rawValue,
        pImmutableSamplers: nil
      )
    ]
    var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      pNext: nil,
      flags: 0,
      bindingCount: UInt32(bindings.count),
      pBindings: bindings
    )

    var descriptorSetLayout: VkDescriptorSetLayout? = nil
    vkCreateDescriptorSetLayout(device, &layoutCreateInfo, nil, &descriptorSetLayout)

    self.framebufferDescriptorSetLayout = descriptorSetLayout!
  }

  func createFramebufferDescriptorSets() throws {
    var setLayouts = Array(repeating: Optional(framebufferDescriptorSetLayout), count: swapchainImages.count)
    var allocateInfo = VkDescriptorSetAllocateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
      pNext: nil,
      descriptorPool: descriptorPool,
      descriptorSetCount: UInt32(swapchainImages.count),
      pSetLayouts: setLayouts
    )

    var descriptorSets = [VkDescriptorSet?](repeating: nil, count: swapchainImages.count)
    
    vkAllocateDescriptorSets(device, &allocateInfo, &descriptorSets)

    framebufferDescriptorSets = descriptorSets.map { $0! }

    //var descriptorWrites = [VkWriteDescriptorSet](repeating: VkWriteDescriptorSet(), count: swapchainImageViews.count)
    var imageInfos = [VkDescriptorImageInfo](repeating: VkDescriptorImageInfo(), count: swapchainImageViews.count)

    for (index, imageView) in swapchainImageViews.enumerated() {
      imageInfos[index] = VkDescriptorImageInfo(
        sampler: nil,
        imageView: imageView,
        imageLayout: VK_IMAGE_LAYOUT_GENERAL
      )
    }

    for index in 0..<swapchainImageViews.count {
      var write = VkWriteDescriptorSet(
        sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext: nil,
        dstSet: descriptorSets[index],
        dstBinding: 0,
        dstArrayElement: 0,
        descriptorCount: 1,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
        pImageInfo: &imageInfos[index],
        pBufferInfo: nil,
        pTexelBufferView: nil
      )

      // currently need to perform the write here instead of in bulk, because otherwise
      // there are some memory issues and the write is not executed
      // correctly for some reason
      vkUpdateDescriptorSets(device, 1, &write, 0, nil)
    }
 }

  func createSceneDescriptorSetLayout() throws {
    var samplers = [Optional(textureSampler)]
    var bindings: [VkDescriptorSetLayoutBinding] = [
      VkDescriptorSetLayoutBinding(
        binding: 0,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        descriptorCount: 1,
        stageFlags: VK_SHADER_STAGE_COMPUTE_BIT.rawValue,
        pImmutableSamplers: nil
      )
    ]

    var layoutCreateInfo = VkDescriptorSetLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      pNext: nil,
      flags: 0,
      bindingCount: UInt32(bindings.count),
      pBindings: bindings
    )

    var descriptorSetLayout: VkDescriptorSetLayout? = nil
    vkCreateDescriptorSetLayout(device, &layoutCreateInfo, nil, &descriptorSetLayout)

    self.sceneDescriptorSetLayout = descriptorSetLayout!
  }

  func createSceneDescriptorSet() throws {
    var setLayouts = [Optional(sceneDescriptorSetLayout)]
    var allocateInfo = VkDescriptorSetAllocateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
      pNext: nil,
      descriptorPool: descriptorPool,
      descriptorSetCount: 1,
      pSetLayouts: setLayouts
    )

    var sceneDescriptorSet: VkDescriptorSet? = nil
    
    vkAllocateDescriptorSets(device, &allocateInfo, &sceneDescriptorSet)

    self.sceneDescriptorSet = sceneDescriptorSet!
  }

  func updateSceneDescriptorSet() throws {
    var uniformObjectBufferInfo = VkDescriptorBufferInfo(
      buffer: sceneManager.objectGeometryBuffer.buffer,
      offset: 0,
      range: VK_WHOLE_SIZE
    )

    var descriptorWrites: [VkWriteDescriptorSet] = [
      VkWriteDescriptorSet(
        sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext: nil,
        dstSet: sceneDescriptorSet,
        dstBinding: 0,
        dstArrayElement: 0,
        descriptorCount: 1,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        pImageInfo: nil,
        pBufferInfo: &uniformObjectBufferInfo,
        pTexelBufferView: nil
      )
    ]

    vkUpdateDescriptorSets(device, UInt32(descriptorWrites.count), &descriptorWrites, 0, nil)
  }

  func createComputePipeline() throws {
    let shaderModule = try loadShaderModule(resourceName: "compute")

    var shaderStageInfo = VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      pNext: nil,
      flags: 0,
      stage: VK_SHADER_STAGE_COMPUTE_BIT,
      module: shaderModule,
      pName: strdup("main"),
      pSpecializationInfo: nil
    )

    var setLayouts = [Optional(framebufferDescriptorSetLayout), Optional(sceneDescriptorSetLayout)]
    var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
      pNext: nil,
      flags: 0,
      setLayoutCount: UInt32(setLayouts.count),
      pSetLayouts: setLayouts,
      pushConstantRangeCount: 0,
      pPushConstantRanges: nil
    )

    var pipelineLayoutOpt: VkPipelineLayout? = nil
    vkCreatePipelineLayout(device, &pipelineLayoutInfo, nil, &pipelineLayoutOpt)

    guard let pipelineLayout = pipelineLayoutOpt else {
      fatalError("could not create pipeline layout")
    }

    var pipelineCreateInfo = VkComputePipelineCreateInfo(
      sType: VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
      pNext: nil,
      flags: 0,
      stage: shaderStageInfo,
      layout: pipelineLayout,
      basePipelineHandle: nil,
      basePipelineIndex: 0
    )

    var createInfos = [pipelineCreateInfo]
    var pipeline: VkPipeline? = nil
    vkCreateComputePipelines(device, nil, 1, createInfos, nil, &pipeline)

    self.computePipeline = pipeline!
    self.computePipelineLayout = pipelineLayout
  }

  func createCommandPool() throws {
    var commandPoolInfo = VkCommandPoolCreateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      pNext: nil,
      flags: 0,
      queueFamilyIndex: queueFamilyIndex
    )
    var commandPool: VkCommandPool? = nil
    vkCreateCommandPool(device, &commandPoolInfo, nil, &commandPool)
    self.commandPool = commandPool!
  }

  func recordDrawCommandBuffer(framebufferIndex: Int) throws -> VkCommandBuffer {
    var commandBufferInfo = VkCommandBufferAllocateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      pNext: nil,
      commandPool: commandPool,
      level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      commandBufferCount: 1
    )

    var commandBufferOpt: VkCommandBuffer?
    vkAllocateCommandBuffers(device, &commandBufferInfo, &commandBufferOpt)

    guard let commandBuffer = commandBufferOpt else {
      fatalError("could not create command buffer")
    }

    var commandBufferBeginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pNext: nil,
      flags: 0,
      pInheritanceInfo: nil
    )
    vkBeginCommandBuffer(commandBuffer, &commandBufferBeginInfo)

    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, computePipeline)
    var descriptorSets = [Optional(framebufferDescriptorSets[framebufferIndex]), Optional(sceneDescriptorSet)]
    vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, computePipelineLayout, 0, 1, descriptorSets, 0, nil)
    vkCmdDispatch(commandBuffer, 1, 1, 1)

    vkEndCommandBuffer(commandBuffer)

    return commandBuffer
  }

  public func draw() throws {
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

    var waitFences = [acquireFence]
    vkWaitForFences(device, 1, waitFences, 1, 10000000)

    let currentImage = swapchainImages[Int(currentSwapchainImageIndex)]
    try transitionImageLayout(image: currentImage, format: swapchainImageFormat, oldLayout: VK_IMAGE_LAYOUT_UNDEFINED, newLayout: VK_IMAGE_LAYOUT_GENERAL)
    vkDeviceWaitIdle(device)

    let commandBuffer = try recordDrawCommandBuffer(framebufferIndex: Int(currentSwapchainImageIndex))

    var submitCommandBuffers = [Optional(commandBuffer)]
    var submitWaitSemaphores = self.nextDrawSubmitWaits.map { $0.0 } as! [Optional<VkSemaphore>]
    var submitDstStageMasks = self.nextDrawSubmitWaits.map { $0.1 }
    self.nextDrawSubmitWaits = []

    var submitSignalSemaphores = currentDrawFinishSemaphoreCallbacks.flatMap { $0() } as! [VkSemaphore?]

    var submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      pNext: nil,
      waitSemaphoreCount: UInt32(submitWaitSemaphores.count),
      pWaitSemaphores: submitWaitSemaphores,
      pWaitDstStageMask: submitDstStageMasks,
      commandBufferCount: 1,
      pCommandBuffers: submitCommandBuffers,
      signalSemaphoreCount: UInt32(submitSignalSemaphores.count),
      pSignalSemaphores: submitSignalSemaphores
    )
    vkQueueSubmit(queue, 1, &submitInfo, nil)

    vkDeviceWaitIdle(device)

    try transitionImageLayout(image: currentImage, format: swapchainImageFormat, oldLayout: VK_IMAGE_LAYOUT_GENERAL, newLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR)
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
  }
}