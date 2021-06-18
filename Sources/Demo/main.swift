import Foundation
import Dispatch
import GfxMath
import Swim
import SwiftVulkanRenderer

let mainMaterial = Material(texture: Swim.Image(width: 1, height: 1, value: 1))

let scene = Scene()
scene.objects.append(SceneObject(mesh: Mesh.cuboid(material: mainMaterial), transformationMatrix: .identity))
scene.objects.append(SceneObject(mesh: Mesh.icosahedron(material: mainMaterial), transformationMatrix: FMat4([
	1, 0, 0, -2,
	0, 1, 0, 3,
	0, 0, 1, 0,
	0, 0, 0, 1
])))
scene.objects.append(SceneObject(mesh: Mesh.sphere(subdivisionCount: 4, material: mainMaterial), transformationMatrix: FMat4([
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

let application = VulkanRendererApplication(scene: scene) 

DispatchQueue.global().async {
	var nextX = Float(0)
	while true {
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

		DispatchQueue.main.async {
			try! application.notifySceneContentsUpdated()
		}
		sleep(1)
	}
}

application.beforeFrame = { _ in
	scene.directionalLight.direction.x = sin(Float(Date.timeIntervalSinceReferenceDate))
	scene.directionalLight.direction.z = cos(Float(Date.timeIntervalSinceReferenceDate))
}

try application.run()