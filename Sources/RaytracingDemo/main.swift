import Foundation
import Dispatch
import GfxMath
import Swim
import SwiftVulkanRenderer

let mainMaterial = Lambertian(texture: Swim.Image(width: 1, height: 1, color: Swim.Color(r: 120, g: 250, b: 240, a: 255)))
let secondMaterial = Dielectric(refractiveIndex: 1.2)
let thirdMaterial = Lambertian(texture: Swim.Image(width: 1, height: 1, color: Swim.Color(r: 50, g: 60, b: 210, a: 255)))

let scene = Scene()
scene.objects.append(SceneObject(mesh: Mesh.cuboid(), material: mainMaterial, transformationMatrix: FMat4([
	1, 0, 0, -2,
	0, 1, 0, 2,
	0, 0, 1, 0,
	0, 0, 0, 1
])))

scene.objects.append(SceneObject(mesh: Mesh.cuboid(), material: secondMaterial, transformationMatrix: FMat4([
	1, 0, 0, 2,
	0, 1, 0, 0.5,
	0, 0, 1, 1,
	0, 0, 0, 1
])))

scene.objects.append(SceneObject(mesh: Mesh.sphere(subdivisionCount: 1), material: secondMaterial, transformationMatrix: FMat4([
	1, 0, 0, -1,
	0, 1, 0, 0.8,
	0, 0, 1, 2,
	0, 0, 0, 1
])))

scene.objects.append(SceneObject(mesh: Mesh.cuboid(), material: thirdMaterial, transformationMatrix: FMat4([
	30, 0, 0, -2,
	0, 1, 0, -1,
	0, 0, 30, 0,
	0, 0, 0, 1
])))
/*
scene.objects.append(SceneObject(mesh: Mesh.cuboid(), material: secondMaterial, transformationMatrix: FMat4([
	10, 0, 0, 2,
	0, 1, 0, -20,
	0, 0, 10, 0,
	0, 0, 0, 1
])))*/

/*
scene.objects.append(SceneObject(mesh: Mesh.sphere(subdivisionCount: 4, material: secondMaterial), transformationMatrix: FMat4([
	1, 0, 0, -6,
	0, 1, 0, 3,
	0, 0, 1, 0,
	0, 0, 0, 1
])))
scene.objects.append(SceneObject(mesh: Mesh.cylinder(divisionCount: 20, material: mainMaterial), transformationMatrix: FMat4([
	1, 0, 0, -10,
	0, 1, 0, 3,
	0, 0, 1, 0,
	0, 0, 0, 1
])))*/

scene.camera.position = FVec3(0, 3, -10)

let application = try VulkanRendererApplication(createRenderer: {
	try RaytracingVulkanRenderer(scene: scene, config: $0)
}, scene: scene) 


DispatchQueue.global().async {
	var nextX = Float(0)
	while true {
		DispatchQueue.main.async {
			scene.objects.append(SceneObject(mesh: Mesh.cuboid(), material: mainMaterial, transformationMatrix: FMat4([
				1, 0, 0, nextX,
				0, 1, 0, 0,
				0, 0, 1, 0,
				0, 0, 0, 1
			])))
			nextX += 1
			
			scene.objects[0].transformationMatrix = FMat4([
				1, 0, 0, 0,
				0, 1, 0, nextX,
				0, 0, 1, 0,
				0, 0, 0, 1
			])

			try! application.notifySceneContentsUpdated()
		}
		sleep(1)
	}
}

var frameCount = 0

application.beforeFrame = { _ in
	frameCount += 1
	if frameCount > 2000 {
		exit(0)
	}
	scene.directionalLight.direction.x = Float(sin(Date.timeIntervalSinceReferenceDate))
	scene.directionalLight.direction.z = Float(cos(Date.timeIntervalSinceReferenceDate))

	usleep(UInt32(1e4))
}

try application.run()