import Foundation
import Vulkan

public class RaytracingVulkanRenderer: VulkanRenderer {
  public static let drawTargetFormat: VkFormat = VK_FORMAT_B8G8R8A8_UNORM

  public let device: VkDevice
  public let physicalDevice: VkPhysicalDevice
  public let queueFamilyIndex: UInt32
  public let queue: VkQueue

  let scene: Scene

  @Deferred var drawTargetExtent: VkExtent2D
  @Deferred var drawTargetImages: [VkImage]
  @Deferred var drawTargetImageViews: [VkImageView]

  @Deferred var textureSampler: VkSampler

  @Deferred var descriptorPool: VkDescriptorPool
  @Deferred var framebufferDescriptorSetLayout: VkDescriptorSetLayout
  @Deferred var framebufferDescriptorSets: [VkDescriptorSet]
  @Deferred var sceneDescriptorSetLayout: VkDescriptorSetLayout
  @Deferred var sceneDescriptorSet: VkDescriptorSet

  @Deferred var computePipeline: VkPipeline
  @Deferred var computePipelineLayout: VkPipelineLayout
  @Deferred public var commandPool: VkCommandPool

  @Deferred var materialSystem: MaterialSystem
  @Deferred var sceneManager: SceneManager
  
  var nextDrawSubmitWaits: [(VkSemaphore, VkPipelineStageFlags)] = []

  typealias CurrentDrawFinishSemaphoreCallback = () -> [VkSemaphore]
  var currentDrawFinishSemaphoreCallbacks = [CurrentDrawFinishSemaphoreCallback]()

  public init(scene: Scene, config: VulkanRendererConfig) throws {
    self.physicalDevice = config.physicalDevice
    self.device = config.device
    self.queueFamilyIndex = config.queueFamilyIndex
    self.queue = config.queue
    self.scene = scene

    try createTextureSampler()

    try createCommandPool()

    materialSystem = try MaterialSystem(renderer: self)

    sceneManager = try SceneManager(renderer: self)
  } 

  public func setupDrawTargets(extent: VkExtent2D, images: [VkImage], imageViews: [VkImageView]) throws {
    self.drawTargetExtent = extent
    self.drawTargetImages = images
    self.drawTargetImageViews = imageViews

    try createDescriptorPool()

    try createFramebufferDescriptorSetLayout()

    try createFramebufferDescriptorSets()

    try createSceneDescriptorSetLayout()

    try createSceneDescriptorSet()
  
    try createComputePipeline()
  }

  public func updateSceneContent() throws {
    try sceneManager.updateObjectGeometryData()
  }

	public func updateSceneObjectMeta() throws {
    try sceneManager.updateObjectDrawInfoData()
  }

  /// note: has no effect on this renderer, camera stuff handled via push constants on every frame automatically 
  public func updateSceneCameraUniforms() throws {
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
        descriptorCount: 3
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
        descriptorCount: UInt32(drawTargetImages.count)
      )
    ]
    var createInfo = VkDescriptorPoolCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
      pNext: nil,
      flags: VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT.rawValue,
      maxSets: UInt32(drawTargetImages.count) + 1,
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
    var setLayouts = Array(repeating: Optional(framebufferDescriptorSetLayout), count: drawTargetImages.count)
    var allocateInfo = VkDescriptorSetAllocateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
      pNext: nil,
      descriptorPool: descriptorPool,
      descriptorSetCount: UInt32(drawTargetImages.count),
      pSetLayouts: setLayouts
    )

    var descriptorSets = [VkDescriptorSet?](repeating: nil, count: drawTargetImages.count)
    
    vkAllocateDescriptorSets(device, &allocateInfo, &descriptorSets)

    framebufferDescriptorSets = descriptorSets.map { $0! }

    //var descriptorWrites = [VkWriteDescriptorSet](repeating: VkWriteDescriptorSet(), count: drawTargetImageViews.count)
    var imageInfos = [VkDescriptorImageInfo](repeating: VkDescriptorImageInfo(), count: drawTargetImageViews.count)

    for (index, imageView) in drawTargetImageViews.enumerated() {
      imageInfos[index] = VkDescriptorImageInfo(
        sampler: nil,
        imageView: imageView,
        imageLayout: VK_IMAGE_LAYOUT_GENERAL
      )
    }

    for index in 0..<drawTargetImageViews.count {
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
      ),
      VkDescriptorSetLayoutBinding(
        binding: 1,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        descriptorCount: 1,
        stageFlags: VK_SHADER_STAGE_COMPUTE_BIT.rawValue,
        pImmutableSamplers: nil
      ),
      VkDescriptorSetLayoutBinding(
        binding: 2,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        descriptorCount: 1,
        stageFlags: VK_SHADER_STAGE_COMPUTE_BIT.rawValue,
        pImmutableSamplers: nil
      ),
      VkDescriptorSetLayoutBinding(
        binding: 3,
        descriptorType: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
        descriptorCount: UInt32(materialSystem.materialImages.count),
        stageFlags: VK_SHADER_STAGE_COMPUTE_BIT.rawValue,
        pImmutableSamplers: nil
      ),
      VkDescriptorSetLayoutBinding(
        binding: 4,
        descriptorType: VK_DESCRIPTOR_TYPE_SAMPLER,
        descriptorCount: 1,
        stageFlags: VK_SHADER_STAGE_COMPUTE_BIT.rawValue,
        pImmutableSamplers: samplers
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

    var objectGeometryBufferInfo = VkDescriptorBufferInfo(
      buffer: sceneManager.objectGeometryBuffer.buffer,
      offset: 0,
      range: VK_WHOLE_SIZE
    )
    var objectDrawInfoBufferInfo = VkDescriptorBufferInfo(
      buffer: sceneManager.objectDrawInfoBuffer.buffer,
      offset: 0,
      range: VK_WHOLE_SIZE
    )
    var materialDrawInfoBufferInfo = VkDescriptorBufferInfo(
      buffer: materialSystem.materialDataBuffer.buffer,
      offset: 0,
      range: VK_WHOLE_SIZE
    )
    var textureInfos = materialSystem.materialImages.map {
      VkDescriptorImageInfo(
        sampler: nil,
        imageView: $0.imageView,
        imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
      )
    }

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
        pBufferInfo: &objectGeometryBufferInfo,
        pTexelBufferView: nil
      ),
      VkWriteDescriptorSet(
        sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext: nil,
        dstSet: sceneDescriptorSet,
        dstBinding: 1,
        dstArrayElement: 0,
        descriptorCount: 1,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        pImageInfo: nil,
        pBufferInfo: &objectDrawInfoBufferInfo,
        pTexelBufferView: nil
      ),
      VkWriteDescriptorSet(
        sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext: nil,
        dstSet: sceneDescriptorSet,
        dstBinding: 2,
        dstArrayElement: 0,
        descriptorCount: 1,
        descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        pImageInfo: nil,
        pBufferInfo: &materialDrawInfoBufferInfo,
        pTexelBufferView: nil
      ),
      VkWriteDescriptorSet(
        sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        pNext: nil,
        dstSet: sceneDescriptorSet,
        dstBinding: 3,
        dstArrayElement: 0,
        descriptorCount: UInt32(textureInfos.count),
        descriptorType: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
        pImageInfo: &textureInfos,
        pBufferInfo: nil,
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
    var pushConstantRanges = [
      VkPushConstantRange(
        stageFlags: VK_SHADER_STAGE_COMPUTE_BIT.rawValue,
        offset: 0,
        size: UInt32(PushConstantBlock.serializedSize)
      )
    ]
    var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
      pNext: nil,
      flags: 0,
      setLayoutCount: UInt32(setLayouts.count),
      pSetLayouts: setLayouts,
      pushConstantRangeCount: UInt32(pushConstantRanges.count),
      pPushConstantRanges: pushConstantRanges
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

  func recreateComputePipeline() throws {
    vkDestroyPipeline(device, computePipeline, nil)
    vkDestroyDescriptorSetLayout(device, sceneDescriptorSetLayout, nil)
    var descriptorSets = [Optional(sceneDescriptorSet)]
    vkFreeDescriptorSets(device, descriptorPool, 1, descriptorSets)
    try createSceneDescriptorSetLayout()
    try createSceneDescriptorSet()
    try createComputePipeline()
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

    let pushConstant = PushConstantBlock(
      cameraPosition: scene.camera.position,
      cameraForwardDirection: scene.camera.forward,
      cameraRightDirection: scene.camera.right,
      cameraFov: scene.camera.fov,
      objectCount: UInt32(scene.objects.count)
    )
    let pushConstantSize = PushConstantBlock.serializedSize
    let pushConstantData = pushConstant.serializedData
    pushConstantData.withUnsafeBytes {
      vkCmdPushConstants(commandBuffer, computePipelineLayout, VK_SHADER_STAGE_COMPUTE_BIT.rawValue, 0, UInt32(pushConstantSize), $0.baseAddress)
    }

    var descriptorSets = [Optional(framebufferDescriptorSets[framebufferIndex]), Optional(sceneDescriptorSet)]
    vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, computePipelineLayout, 0, UInt32(descriptorSets.count), descriptorSets, 0, nil)
    vkCmdDispatch(commandBuffer, 64, 64, 1)

    vkEndCommandBuffer(commandBuffer)

    return commandBuffer
  }

  public func draw(targetIndex: Int, finishFence: VkFence?) throws {
    try sceneManager.syncUpdate()

    let currentImage = drawTargetImages[Int(targetIndex)]

    let commandBuffer = try recordDrawCommandBuffer(framebufferIndex: Int(targetIndex))

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
    vkQueueSubmit(queue, 1, &submitInfo, finishFence)

    /*try sceneManager.syncUpdate()

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

    let currentImage = drawTargetImages[Int(currentSwapchainImageIndex)]
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
    vkQueuePresentKHR(queue, &presentInfo)*/
  }
}