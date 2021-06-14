import Vulkan
import GfxMath

public struct SceneUniformObject {
	public var viewMatrix: Matrix4<Float>
	public var projectionMatrix: Matrix4<Float> = .zero
	
	public static var serializedSize: Int {
		MemoryLayout<Float>.size * 32
	}

	public var serializedData: [Float] {
		viewMatrix.transposed.elements + projectionMatrix.transposed.elements
	}
}