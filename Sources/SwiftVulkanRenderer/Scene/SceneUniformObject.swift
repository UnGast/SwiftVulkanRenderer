import Vulkan
import GfxMath

public struct SceneUniformObject: BufferSerializableStruct {
	public var viewMatrix: Matrix4<Float>
	public var projectionMatrix: Matrix4<Float>
	public var ambientLightColor: FpRGBColor<Float>
	public var ambientLightIntensity: Float
	public var directionalLightDirection: FVec3
	public var directionalLightColor: FpRGBColor<Float>
	public var directionalLightIntensity: Float

	public static var serializationMeasureInstance: SceneUniformObject {
		SceneUniformObject(
			viewMatrix: .zero,
			projectionMatrix: .zero, 
			ambientLightColor: .white,
			ambientLightIntensity: 0,
			directionalLightDirection: .zero,
			directionalLightColor: .white,
			directionalLightIntensity: 0)
	}
	
	/*public static var serializedSize: Int {
		MemoryLayout<Float>.size * (32 + 20)
	}

	public var serializedData: [Float] {
		var serialized = viewMatrix.transposed.elements + projectionMatrix.transposed.elements
		serialized += [ambientLightColor.r, ambientLightColor.g, ambientLightColor.b, 0] + [ambientLightIntensity, 0, 0, 0]
		serialized += directionalLightDirection.elements + [0, directionalLightColor.r, directionalLightColor.g, directionalLightColor.b, 0]
		serialized += [directionalLightIntensity, 0, 0, 0]
		return serialized
	}*/
}