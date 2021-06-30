import GfxMath

extension RaytracingVulkanRenderer {
	struct ObjectDrawInfo: BufferSerializableStruct {
		var transformationMatrix: FMat4
		var firstVertexIndex: UInt32
		var vertexCount: UInt32
		var materialIndex: UInt32

		static var serializationMeasureInstance: Self {
			Self(transformationMatrix: .zero, firstVertexIndex: 0, vertexCount: 0, materialIndex: 0)
		}
	}
}