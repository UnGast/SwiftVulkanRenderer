import GfxMath

public struct SceneObjectDrawInfo {
	public var transformationMatrix: FMat4

	public var serializedSize: Int {
		MemoryLayout<Float>.size * 16
	}

	public var serializedData: [Float] {
		transformationMatrix.transposed.elements
	}
}