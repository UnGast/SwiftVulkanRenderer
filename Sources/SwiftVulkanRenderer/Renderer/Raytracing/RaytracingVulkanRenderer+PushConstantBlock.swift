import GfxMath

extension RaytracingVulkanRenderer {
	struct PushConstantBlock: BufferSerializableStruct {
		var cameraPosition: FVec3
		var cameraForwardDirection: FVec3 
		var cameraRightDirection: FVec3 
		var triangleCount: UInt32
		
		static var serializationMeasureInstance: Self {
			Self(cameraPosition: .zero, cameraForwardDirection: .zero, cameraRightDirection: .zero, triangleCount: 0)
		}
	}
}