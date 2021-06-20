import GfxMath

public struct SceneObjectDrawInfo {
	public var transformationMatrix: FMat4

	public static var serializedSize: Int {
		MemoryLayout<Float>.size * 16
	}

	public var serializedData: [Float] {
		transformationMatrix.transposed.elements
	}
}