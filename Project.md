# Shadertoy Ray Marcher

This is a ray marcher made to run on shadertoy as an online demo.

## Mission Statements

- Almost-realtime frame times (45-60fps, but aiming for ~60)
- Documentation throughout the code
- Largely configurable settings and definitions in "Common" tab
- Good UX for scene parsing and creation
- Cutting compile time via checking definitions
- Optimized compiling from chosen settings
- Full post engine
- Super user-friendly scene descriptors
	- Tree structure
	- No definitions for number of lights, objects, etc.
	- One source of truth
	- No duplicate parameters (ex. rayPosition (p) for sdfs)

## Goals

- Almost real-time ray marching
	- G-Buffer Pass
	- BDRF renderer
	- MIS + NEE
	- Denoiser
	- TAA
- Some entity translations
	- Rotation
	- Translation
	- Scaling
- Limited metric changes
	- Length 2, 4, and 8
- Some entity modifiers
	- Elongation
	- Extrusion
	- Rounding / Inflating
	- Revolutions
- Some entity distortions
	- Displacement
	- Twist
	- Bend
	- Onion
	- Symmetry (bounded & exact)
	- Repetition (infinite & bounded)
- Limited SDFs declared by “enum”
	- Sphere
	- Box + Rounded Box + Frame Box
	- Torus
	- Cone
	- Plane
	- Cylinder
	- Octohedron
	- Custom
- Smart-compile via definitions
- Preset scenes and a separate spot for a custom one
- Camera movement via iMouse
- Be able to turn off all performance optimizations and post via definitions 
	- Should be able to turn it into a stock ray marcher
- Full post engine
	- SRGB
	- Tone Mapping
	- Exposure
	- Vignette
	- Fog
	- SSAO
- Acceleration structures to greatly speed up the rendering

## Technical

- Scenes will be lists of functions, defined by macros
- Passes
	- Pass One - GBuffer pass
		- Return Color
			- R - Distance
			- G - ==Empty==
			- B - ==Empty==
			- A - ==Empty==
	- Pass Two - Render pass
		- Either 4 or 6 tap normal esimation
		- Return Color
			- R - Hit Distance
			- G - ==Empty==
			- B - Packed Normal P1
			- A - Packed Normal P2
	- Pass Three - BDRF Render
		- BDRF Evaluation
		- MIS + NEE
		- AABB Variance Clip
	- Pass Four - Denoiser
		- Edge-Avoiding À-Trous Wavelet Transform
	- Pass Five (Image Out) - Post Processing
		- Exposure
		- SRGB
		- Tone-Mapping

#### Common File

- Settings
	- Ray Marching Settings
		- MAX_STEPS_RAY_MARCHING - int
	- Render Settings
		- SKYBOX_COLOR_MULT - float
		- MAX_BOUNCES - int
		- NUM_SAMPLES - int
		- ANTI_ALIASING - bool - 0/1
		- ACCUMULATION - bool - 0/1
	- Camera Settings
		- CAMERA_CENTER - vec3
		- CAMERA_Z_OFFSET - float
		- FOV - float
		- INITIAL_CAMERA_YAW - float
		- INITIAL_CAMERA_PITCH - float
		- INITIAL_CAMERA_ROLL - float
	- Post Processing Settings
		- EXPOSURE - float
		- TONE_MAPPING - bool - 0/1
		- SRGB - bool - 0/1
		- DENOISE - bool - 0/1
	- Definitions
	- Numbers
		- PI - 3.1415927
		- TWO_PI - 6.2831853
		- INVERSE_PI - 0.31830989
		- INVERSE_TWO_PI - 0.15915494
		- EULERS - 2.7182818
		- EPSILON - 0.001
		- MIN_CAMERA_ANGLE - 0.1
		- MAX_CAMERA_ANGLE - (PI - MIN_CAMERA_ANGLE)
		- FAR - 50.0 <!-- This is used as the max distance -->
	- Structs
	- Ray
		- origin: vec3
		- direction: vec3
	- Material
		- color: vec3
		- emmisive: vec3
		- roughness: float
		- metallic: float
	- SDFInfo
		- dist: float
		- normal: vec3 <!-- for analytical normals -->
		- materialID: int
	- HitInfo
		- hit: bool
		- distance: float
		- hitPosition: vec3
		- normal: vec3
		- materialID: int
	- LightSample <!--This is used for MIS and hit probabilities -->
		- direction
		- radiance
		- distance
		- pdf
	- Global Values
		- seed: uint
	- Helpers
		- getCameraState(out vec3 cameraPos, out vec3 cameraFwd, out vec3 cameraUp, out vec3 cameraRight)
		- getBackupSeed(vec2 fragCoord, uint inputSeed) -> ==uint==
			- This creates a random seed via math
		- setSeed(vec2 fragCoord, uint inputSeed, sampler2D noise)
			- This updates the global seed value via the given noise texture;
			- Calls "getBackupSeed" when empty noise texture
		- wangHash() -> ==uint==
			- Uses wang hashing algorithm against seed, updates it, and returns it
		- randomNormalizedFloatOne() -> ==uint==
			- Calls wang_hash, sets the seed that, and returns it
			- Normalizes value to uint(-1) (0-1 - theoretically inclusive)
		- randomUnitVector() -> ==vec3==
			- Calls wang_hash twice and figures out the third
			- Internally updates seed
		- halton(int inputSeed) -> ==vec2==
			- Returns halton series via a seed
		- signNotZero(vec2 v) -> ==vec2==
			- Helper  to prevent sin(0.0) from returning 0.0
		- packNormal(vec3 normal) -> ==vec2==
			- Packs the vec3 normal into a vec2
			- Calls signNotZero
			- Lossy
		- unpackNormal(vec2 packedNormal) -> ==vec3==
			- Unpacks the (packed) vec2 normal back into a vec3
			- Calls signNotZero
			- Lossless
		- fetchMaterial(out Material material, int materialID)
			- Fetches the material by materialID
		- unpackGBuffer(const in Ray ray, out HitInfo hit, out Material material, in sampler2D gBufferChannel, vec2 fragCoord) -> ==bool==
			- Fetches the gBuffer values from the sampler2D
			- Calls unpackNormal & fetchMaterial
			- Returns the hit boolean
		- reconstructWorld(vec2 fragCoord, float depth, vec2 cameraOffset) -> ==vec3==
			- Calls getCameraState
			- Returns the hit position in the world in a vec3
		- projectToScreen(vec3 worldPos, vec2 cameraOffset, vec2 resolution) -> ==vec2==
			- Calls getCameraState
			- Returns the screen position in a vec2
	- Intersection Functions <!-- "function name" - "macro name" -->
		- sphereSDF(vec3 rayPosition, vec3 origin, float radius, int materialID) - SPHERE
		- boxSDF(vec3 rayPosition, vec3 normal, float height, int materialID) - BOX
		- roundedBoxSDF - ROUNDED_BOX
		- coneSDF - CONE
		- planeSDF - PLANE
		- cylinderSDF - CYLINDER
	- Entity Transformations / Distortions / Modifiers <!-- "function name" - "macro name" -->
		- Boolean Operations
			- unionOperation - UNION
			- subtractOperation - SUBTRACT
			- intersectOperation - INTERSECT
		- Smooth Boolean Operations
			- smoothUnionOperation - sUNION
			- smoothSubtractOperation - sSUBTRACT
			- smoothIntersectOperation - sINTERSECT
		- Modifiers
			- rotateOperation - ROTATE
			- scaleOperation - SCALE
			- spinOperation - SPIN
			- extrudeOperation - EXTRUDE
			- elongateOperation - ELONGATE
		- Distortions (Space)
			- infiniteRepetitionOperation - iREPETITION
			- boundedRepetitionOperation - bREPETITION
			- symmetryOperation - SYMMETRY
		- Distortions (Object)
			- twistOperation
			- bendOperation
	- Macros
		- SCENE - Calls the map function (defined in macro) against the given sdf tree

### Methods

- Pass 1 - G-Buffer
	- marchRay(const in Ray ray) -> ==HitInfo==
	- estimateNormal(const in Ray ray, const in Hit initialHit) -> ==vec3==
- Pass 2 - BDRF Render
	- marchRay(const in Ray ray) -> ==HitInfo==
	- estimateNormal(const in Ray ray, const in HitInfo initialHit) -> ==vec3==
	- processBounce(inout Ray ray, const in HitInfo hit, const in Material)
	- colorSky(const in Ray ray) -> ==vec3==
	- colorScene(const in Ray ray, vec2 fragCoord) -> ==vec3==
- Pass 3 - Denoiser
- Pass 4 - ==Empty==
- Pass 5 (Image Out) Post Processing
  - lessThan(vec3 input, float comparator) -> ==vec3==
    - Returns a boolean (1.0, 0.0) vec3
    - Compares each part of the input vec3 to the comparator
  - linearToSRGB(vec3 rgb) -> ==vec3==
    - Calls lessThan
    - Changes input vec3 "rgb" to srgb color space
  - SRGBToLinear(vec3 srgb) -> ==vec3==
    - Calls lessThan
    - Changes input vec3 "srgb" into rgb color space
  - ACESFilm(vec3 inputColor) -> ==vec3==
    - Tone maps the inputColor and returns the output color

## Files

- [[Todo|Todo.md]] - Contains important todos, goals, and checklists for use during development

## Resources

- [Inigo-quilez sdf and sdf operations (3d)](https://iquilezles.org/articles/distfunctions/)
- [Analytic Normal Solutions from IQ](https://iquilezles.org/articles/distgradfunctions3d/)
- [fBM with SDFs](https://iquilezles.org/articles/fbmsdf/)

## AI Use

- Tree definition: [https://share.google/aimode/vM5EvYNRlcU90GUNV]
- Cone Marching Quick Idea & Normals: [https://share.google/aimode/ZJKYmMqPIHMsFPhcw](https://share.google/aimode/ZJKYmMqPIHMsFPhcw)
- Scene macro understatement (yea, I didn't need this, it was pretty obvious, just missed it): [https://share.gemini.google/xv6wvrBcVAlF]