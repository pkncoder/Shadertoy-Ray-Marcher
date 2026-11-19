# Shadertoy Ray Marcher

This is a ray marcher made to run on shadertoy as an online demo.

## Mission Statements

- Almost-realtime frame times (45-60fps, but aiming)
- Documentation throughout the code
- Largely configurable settings and definitions in "Common" tab
- Good UX for scene parsing and creation
- Cutting compile time via checking definitions

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
	- Cone
	- Cylinder
	- Custom
- Smart-compile via definitions
- Preset scenes and a separate spot for a custom one
- Camera movement via iMouse

## Technical

- Scenes will be lists of functions, defined by macros
- Passes
	- Pass One - Wide Cone Marching
		- Wide Cone Marching
		- Return Color
			- R - Distance
			- G - ==Empty==
			- B - ==Empty==
			- A - ==Empty==
	- Pass Two - G-Buffer Ray Marching
		- Narrow Ray Marching
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
		- MAX_STEPS_CONE_MARCHING
		- MAX_STEPS_RAY_MARCHING
	- Camera Settings
		- CAMERA_POSITION
		- INITIAL_CAMERA_YAW
		- INITIAL_CAMERA_PITCH
		- INITIAL_CAMERA_ROLL
		- FOV - float
	- Render Settings
		- ANTI_ALIASING - int - 0/1
	- Post Processing Settings
		- TONE_MAPPING - int 0/1
		- SRGB - int 0/1
		- EXPOSURE - float
		- DENOISE - int 0/1
- Definitions
	- MIN_CAMERA_ANGLE - 0.1
	- MAX_CAMERA_ANGLE - (PI - MIN_CAMERA_ANGLE)
- Numbers
	- PI - 3.1415927
	- TWO_PI - 6.2831853
	- INVERSE_PI - 0.31830989
	- INVERSE_TWO_PI - 0.15915494
	- EULERS - 2.7182818
	- EPSILON - 0.001
	- FAR - 50.0 <!-- This is used as the max distance -->
- Structs
	- Ray
		- origin: vec3
		- direction: vec3
	- HitInfo
		- hit: bool
		- distance: float
		- hitPosition: vec3
		- normal: vec3
	- Material
		- color: vec3
		- emmisive: vec3
		- roughness: float
		- metallic: float
	- LightSample <!--This is used for MIS and hit probabilities -->
		- direction
		- radiance
		- distance
		- pdf
- Global Values
	- seed: uint
	- scene: Scene
	- cameraYaw: float
	- cameraPitch: float
	- cameraRoll: float
- Helpers
	- getCameraState(vec2 cameraOffset, out vec3 cameraPos, out vec3 cameraFwd, out vec3 cameraUp, out vec3 cameraRight)
	- setSeed(vec2 fragCoord, uint inputSeed, sampler2D noise) 
		- This updates the global seed value via the given noise texture; 
		- Calls "getBackupSeed" when empty noise texture
	- getBackupSeed(vec2 fragCoord, uint inputSeed) -> ==uint==
		- This creates a random seed via math
	- wangHash() -> ==uint==
		- Uses wang hashing algorithm against seed, updates it, and returns it
	- randomNormalizedFloatOne() -> ==uint==
		- Calls wang_hash, sets the seed that, and returns it
		- Normalizes value to uint(-1) (0-1 - theoretically inclusive)
	- randomNormalizedUnitVector() -> ==vec3==
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
	- unpackGBuffer(const in Ray ray, out HitInfo hit, out Material material, in sampler2D gBuffer, vec2 fragCoord) -> ==bool==
		- Fetches the gBuffer values from the sampler2D
		- Calls unpackNormal
		- Returns the hit boolean
	- reconstructWorld(vec2 fragCoord, float depth, vec2 cameraOffset) -> ==vec3==
		- Calls getCameraState
		- Returns the hit position in the world in a vec3
	- projectToScreen(vec3 worldPos, vec2 cameraOffset, vec2 resolution) -> ==vec2==
		- Calls getCameraState
		- Returns the screen position in a vec2
- Intersection Functions <!-- "function name" - "macro name" -->
	- sphereSDF - SPHERE
	- boxSDF - BOX
	- roundedBoxSDF - ROUNDED_BOX
	- coneSDF - CONE
	- planeSDF - PLANE
	- cylinderSDF - CYLINDER
- Entity Transformations / Distortions / Modifiers <!-- "function name" - "macro name" -->
	- Boolean Operations
		- unionOperation - UNION
		- subtractionOperation - SUBTRACT
		- intersectionOperation - INTERSECT
	- Smooth Boolean Operations
		- smoothUnionOperation - sUNION
		- smoothSubtractionOperation - sSUBTRACT
		- smoothIntersectionOperation - sINTERSECT
	- Modifiers
		- rotationOperation - ROTATE
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

- Pass 1 - Wide Cone Marching
- Pass 2 - G-Buffer Ray Marching
- Pass 3 - BDRF Render
- Pass 4 - Denoiser
- Pass 5 (Image Out) Post Processing 
	- lessThan(vec3 input, float comparator) -> vec3
		- Returns a boolean (1.0, 0.0) vec3
		- Compares each part of the input vec3 to the comparator
	- linearToSRGB(vec3 rgb) -> vec3
		- Calls lessThan
		- Changes input vec3 "rgb" to srgb color space
	- SRGBToLinear(vec3 srgb) -> vec3
		- Calls lessThan
		- Changes input vec3 "srgb" into rgb color space
	- ACESFilm(vec3 inputColor) -> vec3
		- Tone maps the inputColor and returns the output color

## Files

- [[Todo|Todo.md]] - Contains important todos, goals, and checklists for use during development

## Resources

- [Inigo-quilez sdf and sdf operations (3d)](https://iquilezles.org/articles/distfunctions/)
- [Analytic Normal Solutions from IQ](https://iquilezles.org/articles/distgradfunctions3d/)
- [fBM with SDFs](https://iquilezles.org/articles/fbmsdf/)

## AI Use

- Tree definition: https://share.google/aimode/vM5EvYNRlcU90GUNV
- Cone Marching Quick Idea & Normals: [https://share.google/aimode/ZJKYmMqPIHMsFPhcw](https://share.google/aimode/ZJKYmMqPIHMsFPhcw)
