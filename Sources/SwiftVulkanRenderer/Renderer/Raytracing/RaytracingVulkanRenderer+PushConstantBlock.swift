import GfxMath

extension RaytracingVulkanRenderer {
	struct PushConstantBlock: SingleScalarArrayBufferSerializable {
		var cameraPosition: FVec3
		var cameraForwardDirection: FVec3 
		var cameraRightDirection: FVec3 
		
		static var serializedBaseAlignment: Int {
			MemoryLayout<Float>.size * 9
		}
		static var serializedSize: Int {
			MemoryLayout<Float>.size * 9
		}

		var serializedData: [Float] {
			cameraPosition.elements + cameraForwardDirection.elements + cameraRightDirection.elements
		}
	}
}