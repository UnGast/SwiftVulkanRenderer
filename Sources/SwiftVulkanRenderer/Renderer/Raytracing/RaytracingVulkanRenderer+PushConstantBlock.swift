import GfxMath

extension RaytracingVulkanRenderer {
	struct PushConstantBlock: SingleScalarArrayBufferSerializable {
		var cameraPosition: FVec3
		var cameraDirection: FVec3 
		
		static var serializedBaseAlignment: Int {
			MemoryLayout<Float>.size * 6
		}
		static var serializedSize: Int {
			MemoryLayout<Float>.size * 6
		}

		var serializedData: [Float] {
			cameraPosition.elements + cameraDirection.elements
		}
	}
}