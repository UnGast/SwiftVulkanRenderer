import GfxMath

public struct SceneObjectDrawInfo: BufferSerializableStruct {
	public var transformationMatrix: FMat4
	public var materialIndex: UInt32

	public static var serializationMeasureInstance: SceneObjectDrawInfo {
		SceneObjectDrawInfo(transformationMatrix: .zero, materialIndex: 0)
	}
}