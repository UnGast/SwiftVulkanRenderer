export DIR=Sources/SwiftVulkanRenderer/Resources
glslc -fshader-stage=vert ${DIR}/vertex.glsl -o ${DIR}/vertex.spv
glslc -fshader-stage=frag ${DIR}/fragment.glsl -o ${DIR}/fragment.spv