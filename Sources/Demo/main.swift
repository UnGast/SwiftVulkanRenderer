import Foundation
import Dispatch
import GfxMath
import Swim
import SwiftVulkanRenderer

let mainMaterial = Material(texture: Swim.Image(width: 10, height: 10, color: Swim.Color(r: 120, g: 50, b: 240, a: 255)))
let secondMaterial = Material(texture: Swim.Image(width: 10, height: 10, color: Swim.Color(r: 220, g: 0, b: 0, a: 255)))

let scene = Scene()
scene.objects.append(SceneObject(mesh: Mesh.cuboid(material: mainMaterial), transformationMatrix: .identity))
scene.objects.append(SceneObject(mesh: Mesh.icosahedron(material: mainMaterial), transformationMatrix: FMat4([
	1, 0, 0, -2,
	0, 1, 0, 3,
	0, 0, 1, 0,
	0, 0, 0, 1
])))
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
])))

scene.camera.position = FVec3(0, 2, -10)

let application = VulkanRendererApplication(scene: scene) 

DispatchQueue.global().async {
	var nextX = Float(0)
	while true {
		DispatchQueue.main.async {
			scene.objects.append(SceneObject(mesh: Mesh.cuboid(material: mainMaterial), transformationMatrix: FMat4([
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

application.beforeFrame = { _ in
	scene.directionalLight.direction.x = Float(sin(Date.timeIntervalSinceReferenceDate))
	scene.directionalLight.direction.z = Float(cos(Date.timeIntervalSinceReferenceDate))
}

try application.run()