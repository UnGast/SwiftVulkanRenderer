import Vulkan
import GfxMath

public struct SceneUniformObject: BufferSerializableStruct {
	public var viewMatrix: Matrix4<Float>
	public var projectionMatrix: Matrix4<Float> = .zero
	public var ambientLightColor: FpRGBColor<Float> = .white
	public var ambientLightIntensity: Float = 0.1
	public var directionalLightDirection: FVec3 = FVec3(0.7, -1, 0)
	public var directionalLightColor: FpRGBColor<Float> = .white
	public var directionalLightIntensity: Float = 0.5

	public static var serializationMeasureInstance: SceneUniformObject {
		SceneUniformObject(viewMatrix: .identity)
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