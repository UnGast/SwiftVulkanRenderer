import Vulkan

public protocol VulkanRenderer {
	var device: VkDevice { get }
	var swapchainExtent: VkExtent2D { get }

	func updateSceneContent() throws
	func updateSceneObjectMeta() throws
	func updateSceneCameraUniforms() throws

	func findMemoryType(typeFilter: UInt32, properties: VkMemoryPropertyFlagBits) throws -> UInt32

	func beginSingleTimeCommands() throws -> VkCommandBuffer

	func endSingleTimeCommands(commandBuffer: VkCommandBuffer, waitSemaphores: [VkSemaphore], signalSemaphores: [VkSemaphore]) throws

	func draw() throws
}

extension VulkanRenderer {
	public func endSingleTimeCommands(commandBuffer: VkCommandBuffer, waitSemaphores: [VkSemaphore] = [], signalSemaphores: [VkSemaphore] = []) throws {
		try endSingleTimeCommands(commandBuffer: commandBuffer, waitSemaphores: waitSemaphores, signalSemaphores: signalSemaphores)
	}
}