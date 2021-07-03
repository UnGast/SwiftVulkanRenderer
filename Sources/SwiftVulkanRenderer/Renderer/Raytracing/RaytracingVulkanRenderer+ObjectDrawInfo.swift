import GfxMath

extension RaytracingVulkanRenderer {
	struct ObjectDrawInfo: BufferSerializableStruct {
		var transformationMatrix: FMat4
		var firstVertexIndex: UInt32
		var vertexCount: UInt32
		var materialIndex: UInt32
		var p: UInt32 = 0 // for unknown reasons, this is necessary for correct data transfer in vulkan (even without it, stride is correct, still doesn't work)

		static var serializationMeasureInstance: Self {
			Self(transformationMatrix: .zero, firstVertexIndex: 0, vertexCount: 0, materialIndex: 0)
		}
	}
}