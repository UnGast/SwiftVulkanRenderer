#version 460
#extension GL_ARB_separate_shader_objects:enable
#extension GL_EXT_nonuniform_qualifier:enable

layout (local_size_x = 8) in;
layout (local_size_y = 8) in;

struct Vertex{
  vec3 position;
  float t1;
  vec3 normal;
  float t2;
};

struct ObjectDrawInfo{
  mat4 transformationMatrix;
  uint firstVertexIndex;
  uint vertexCount;
  uint materialIndex;
};

struct MaterialDrawInfo{
  uint textureIndex;
  float refractiveIndex;
};

struct RaycastInfo {
  vec3 rayOrigin;
  vec3 rayDirection;
  uint rayDepth;
  bool hit;
  vec3 hitPosition;
  vec3 hitNormal;
  uint hitObjectIndex;
  vec3 hitAttenuation;
  vec3 hitEmittance; 
};

layout(push_constant) uniform PushConstants{
  vec3 cameraPosition;
  vec3 cameraForwardDirection;
  vec3 cameraRightDirection;
  uint unusedPlaceholder; // only used because for last value, packing is different? uint will be put directly after vec3 not like other vec3 which are stored like vec4
  float cameraFov;
  uint objectCount;
};
layout(set = 0, binding = 0) uniform writeonly image2D frameImage;
layout(set = 1, binding = 0) buffer VertexBuffer{
  Vertex vertices[];
};
layout(set = 1, binding = 1) buffer ObjectDrawInfoBuffer{
  ObjectDrawInfo objectDrawInfos[];
};
layout(set = 1, binding = 2) buffer MaterialDrawInfoBuffer{
  MaterialDrawInfo materialDrawInfos[];
};

float getAreaOfTriangle(vec3 vertex1Position, vec3 vertex2Position, vec3 vertex3Position) {
  vec3 edge1 = vertex2Position - vertex1Position;
  vec3 edge2 = vertex3Position - vertex1Position; 
  return length(cross(edge1, edge2));
}

vec3 getBarycentricCoordinates(vec3 point, vec3 vertex1Position, vec3 vertex2Position, vec3 vertex3Position) {
  float primaryArea = getAreaOfTriangle(vertex1Position, vertex2Position, vertex3Position);
  float secondaryArea1 = getAreaOfTriangle(vertex1Position, point, vertex2Position);
  float secondaryArea2 = getAreaOfTriangle(vertex2Position, point, vertex3Position);
  float secondaryArea3 = getAreaOfTriangle(vertex3Position, point, vertex1Position);
  float u = secondaryArea1 / primaryArea;
  float v = secondaryArea2 / primaryArea;
  float w = secondaryArea3 / primaryArea;
  return vec3(u, v, w);
}

RaycastInfo makeEmptyRaycastInfo() {
  RaycastInfo raycastInfo;
  raycastInfo.hitAttenuation = vec3(1, 1, 1);
  raycastInfo.hitEmittance = vec3(0, 0, 0);
  raycastInfo.hit = false;
  return raycastInfo;
}

void raycast(inout RaycastInfo raycastInfo) {
  vec3 normalizedRayDirection = normalize(raycastInfo.rayDirection);

  bool hit = false;
  float closestIntersectionScale = 0;

  for (int objectIndex = 0; objectIndex < min(3, objectCount); objectIndex++) {
    ObjectDrawInfo objectDrawInfo = objectDrawInfos[objectIndex];
    MaterialDrawInfo materialDrawInfo = materialDrawInfos[objectDrawInfo.materialIndex];
    uint faceCount = objectDrawInfo.vertexCount / 3;

    for (int faceIndex = 0; faceIndex < faceCount; faceIndex++) {
      uint baseVertexIndex = objectDrawInfo.firstVertexIndex + faceIndex * 3;

      Vertex vertex1 = vertices[baseVertexIndex];
      Vertex vertex2 = vertices[baseVertexIndex + 1];
      Vertex vertex3 = vertices[baseVertexIndex + 2];
      vertex1.position = (objectDrawInfo.transformationMatrix * vec4(vertex1.position, 1)).xyz;
      vertex2.position = (objectDrawInfo.transformationMatrix * vec4(vertex2.position, 1)).xyz;
      vertex3.position = (objectDrawInfo.transformationMatrix * vec4(vertex3.position, 1)).xyz;
      /*vertex1.normal = (objectDrawInfo.transformationMatrix * vec4(vertex1.normal, 0)).xyz;
      vertex2.normal = (objectDrawInfo.transformationMatrix * vec4(vertex2.normal, 0)).xyz;
      vertex3.normal = (objectDrawInfo.transformationMatrix * vec4(vertex3.normal, 0)).xyz;*/

      vec3 edge1 = vertex2.position - vertex1.position;
      vec3 edge2 = vertex3.position - vertex2.position;
      vec3 edge3 = vertex1.position - vertex3.position;

      vec3 faceOrigin = vertex1.position;
      vec3 computedFaceNormal = normalize(cross(edge1, edge2));

      float faceNormalRayDot = dot(computedFaceNormal, normalizedRayDirection);
      if (faceNormalRayDot == 0) {
        continue;
      }

      float intersectionScale = (dot(computedFaceNormal, faceOrigin) - dot(computedFaceNormal, raycastInfo.rayOrigin)) / dot(computedFaceNormal, normalizedRayDirection);

      if (intersectionScale < 0.01) {
        continue;
      }

      if (intersectionScale < closestIntersectionScale || !hit) {
        vec3 intersection = raycastInfo.rayOrigin + normalizedRayDirection * intersectionScale;

        vec3 barycentricIntersection = getBarycentricCoordinates(intersection, vertex1.position, vertex2.position, vertex3.position);

        float barycentricSum = dot(barycentricIntersection, vec3(1, 1, 1));
        if (abs(barycentricSum - 1) <= 0.01) {
          closestIntersectionScale = intersectionScale;
          raycastInfo.hitAttenuation = vec3(0.5, 0.5, 0.5);
          raycastInfo.hitPosition = intersection;
          raycastInfo.hitNormal = vertex1.normal * barycentricIntersection.x + vertex2.normal * barycentricIntersection.y + vertex3.normal * barycentricIntersection.z;
          raycastInfo.hitAttenuation = vec3(float(objectDrawInfo.materialIndex), 0.5, 0.5);
          raycastInfo.hitObjectIndex = objectIndex;
          raycastInfo.hit = true;
          hit = true;
        }
      }
    }
  }

  /*if (!hit) {
    raycastInfo.hitAttenuation = vec3(1, 1, 1);
  }*/

  /*if (raycastInfo.rayDepth < 10) {
    if (hit) {
      RaycastInfo subRaycastInfo = makeEmptyRaycastInfo();
      subRaycastInfo.rayDepth = raycastInfo.rayDepth + 1;
      subRaycastInfo.rayOrigin = raycastInfo.hitPosition;
      subRaycastInfo.rayDirection = raycastInfo.hitNormal;

      raycast(subRaycastInfo);

      raycastInfo.hitAttenuation = raycastInfo.hitAttenuation * subRaycastInfo.hitAttenuation;
    } else {
      raycastInfo.hitAttenuation = vec3(1, 1, 1);
    }
  }*/
}

float rand(vec2 co){
  return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void execute() {
  uvec2 frameImageSize = imageSize(frameImage);
  uint divisionsX = gl_WorkGroupSize.x * gl_NumWorkGroups.x;
  uint divisionsY = gl_WorkGroupSize.y * gl_NumWorkGroups.y;
  uint xRangeStep = uint(ceil(float(frameImageSize.x) / float(divisionsX)));
  uint yRangeStep = uint(ceil(float(frameImageSize.y) / float(divisionsY)));
  uint startX = uint(xRangeStep * gl_GlobalInvocationID.x);
  uint endX = min(frameImageSize.x, uint(ceil(float(startX) + xRangeStep)));
  uint startY = uint(yRangeStep * gl_GlobalInvocationID.y);
  uint endY = min(frameImageSize.y, uint(ceil(float(startY) + yRangeStep)));

  vec3 normalizedCameraForwardDirection = normalize(cameraForwardDirection);
  vec3 surfaceOrigin = cameraPosition + normalizedCameraForwardDirection * 1;
  vec3 surfaceRight = normalize(cameraRightDirection);
  vec3 surfaceUp = normalize(cross(surfaceRight, normalizedCameraForwardDirection));
  float surfaceWidth = tan(cameraFov / 2) * 2;
  vec2 surfaceSize = vec2(surfaceWidth, surfaceWidth / float(frameImageSize.x) * float(frameImageSize.y));

  for (uint x = startX; x < endX; x += 1) {
    for (uint y = startY; y < endY; y += 1) {
      imageStore(frameImage, ivec2(x, y), vec4(0.2, 0.4, 1, 1));

      vec3 imagePointColor = vec3(0, 0, 0);
      int nIterations = 4;

      for (int iterationIndex = 0; iterationIndex < nIterations; iterationIndex++) {
        vec2 relativePositionOnSurface = vec2(float(x) / float(frameImageSize.x), float(y) / float(frameImageSize.y));
        vec2 positionOnSurface = relativePositionOnSurface * surfaceSize;
        vec2 centeredPositionOnSurface = positionOnSurface - surfaceSize / 2;
        vec3 lookAtPoint = surfaceOrigin + centeredPositionOnSurface.x * surfaceRight + centeredPositionOnSurface.y * surfaceUp;

        vec3 nextRayOrigin = cameraPosition;
        vec3 nextRayDirection = normalize(lookAtPoint - cameraPosition);

        RaycastInfo rayResults[4];
        int lastRayResultIndex = 0;
        
        for (int rayDepth = 0; rayDepth < 4; rayDepth++) {
          RaycastInfo raycastInfo = makeEmptyRaycastInfo();
          raycastInfo.rayDepth = rayDepth;
          raycastInfo.rayOrigin = nextRayOrigin;
          raycastInfo.rayDirection = nextRayDirection;

          raycast(raycastInfo); 

          if (!raycastInfo.hit) {
            raycastInfo.hitEmittance = max(0.4, dot(vec3(0.1, 1, 0), raycastInfo.rayDirection)) * vec3(1, 1, 1);
          }

          rayResults[rayDepth] = raycastInfo;

          lastRayResultIndex = rayDepth;

          if (raycastInfo.hit) {
            vec3 normNormal = normalize(raycastInfo.hitNormal);
            float nextDirectionOffset = 2 * dot(raycastInfo.rayDirection, normNormal);
            vec2 randomSeed = vec2(float(x), float(y) + float(iterationIndex));
            nextRayDirection = normalize(vec3(rand(randomSeed), rand(randomSeed), rand(randomSeed)));
            // FOR MIRROR REFLECTION: nextRayDirection = raycastInfo.rayDirection + normNormal * nextDirectionOffset;
            nextRayOrigin = raycastInfo.hitPosition;
          } else {
            break;
          }
        }

        vec3 resultColor = vec3(0, 0, 0);

        for (int rayResultIndex = lastRayResultIndex; rayResultIndex >= 0; rayResultIndex--) {
          resultColor += rayResults[rayResultIndex].hitEmittance;
          resultColor *= rayResults[rayResultIndex].hitAttenuation;
        }

        imagePointColor += resultColor;
      }

      imagePointColor /= float(nIterations);

      imageStore(frameImage, ivec2(x, y), vec4(imagePointColor, 1));
    }
  }
}

void main() {
  execute();
}