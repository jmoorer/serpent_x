VEFECTS - EASY SHOCKWAVES VFX for GODOT
Version 1.0.3

90 shockwave effects: expanding ground rings and vertical shockwaves in three sizes (small, normal, big) and three
durations (500 ms, 1 s, 2 s), in white, nine colors (red, orange, yellow, green, teal, purple, lavender, pink, black)
and a screen distortion version that bends whatever is behind it. Includes the shockwave sounds and the overview demo
scene of the original pack.


REQUIREMENTS
------------
- Godot 4.7 or newer.
- Renderer: Forward+ (recommended).


INSTALLATION
------------
1. Copy the "Vefects" folder into the root of your Godot project (res://).
   The pack must stay at res://Vefects/Easy Shockwaves VFX/.
2. Open the project and let Godot import the files (the first import takes a few minutes).
3. Recommended: Project > Project Settings > Rendering > Textures >
   Anisotropic Filtering Level = 8x
   so the effects stay sharp when seen at grazing angles, as in the original pack.

The Demo Project download already includes this setting and opens the demo scene.


DEMO
----
Open res://Vefects/Easy Shockwaves VFX/Demo/VFX_Demo.tscn and press F6 (Run Current Scene).
  Left / Right (or A / D)  change effect
  Space (or R)             replay
  Right mouse drag         orbit the camera
  Mouse wheel              zoom

The scene res://Vefects/Easy Shockwaves VFX/Demo/Scenes/Vefects Easy Shockwaves VFX Overview Scene.tscn is the overview scene of the original pack: every effect is placed in a
row and plays once when the scene starts.


USING THE EFFECTS
-----------------
Drag any effect scene into your scene, or instance it from code:

    var fx := preload("res://Vefects/Easy Shockwaves VFX/<path to the effect>.tscn").instantiate()
    add_child(fx)
    fx.global_position = hit_position

Every effect plays once; the _500ms, _1s and _2s versions last that long, and _Small / _Big change the
radius. The overview scene renders without post processing, like the original scene.
Effects are GPUParticles3D nodes and play automatically when they enter the scene tree.
To play an effect again, call restart() on its GPUParticles3D nodes, or instance the scene again.
The shockwave sounds of the original pack are in Audio/WAV/ (one per duration and style); play them with an
AudioStreamPlayer3D next to the effect.

To play, pause, stop or restart many effects at once, attach Shared/Scripts/Vefects_VFX_Controller.gd to any parent node
(an effect's root, a group of effects) and use the Play, Pause / Resume, Stop and Restart buttons in the
Inspector, in the editor and in game; from code call play(), pause(), stop() and restart() on that node.
Auto Replay restarts every particle system under it every Replay Interval seconds, one-shot effects included.


FOLDERS
-------
  VFX/Shockwaves/Particles/              white shockwaves (VFX_Shockwave_01_White_*, VFX_Shockwave_Vertical_01_White_*)
  VFX/Shockwaves/Particles/Color Variation/   colored shockwaves (1 s, small / normal / big)
  VFX/Shockwaves Distortion/Particles/   distortion shockwaves (VFX_Shockwave_*_Distortion_*)
  VFX/*/Materials/                       materials (ShaderMaterial; *_Mesh.tres = for regular meshes)
  Shared/Shaders/                        shaders (one .gdshaderinc per shader + one .gdshader per variant)
  Shared/Textures/, Shared/Meshes/       noise, mask and gradient textures, ring and cylinder meshes
  Shared/Scripts/                        helper scripts
  Audio/WAV/                             shockwave sound effects (WAV)
  Demo/Scenes/                           the overview scene of the pack
  Demo/Resources/                        demo environment (sky, floor, character, lighting) and effect layouts
  Demo/                            demo scene


CUSTOMIZING
-----------
The effects use the shaders of Shared/Shaders/ (SH_Vefects_VFX_Easy_Shockwave_URP for the colored shockwaves: eroded panning noises,
an intensity mask, emission, desaturation and a small chromatic aberration; SH_Vefects_VFX_Easy_Shockwave_Distortion_URP
for the distortion shockwaves: it refracts the opaque scene behind the ring with a normal map noise). Each shader is
written once in a .gdshaderinc file; the .gdshader files next to it only choose the culling (the plain files cull back
faces like the original, _Two_Sided draws both sides), and the _Mesh versions draw regular meshes (MeshInstance3D)
instead of particles.
The color of a shockwave is its particle start color ("start_color_a" of the process material of its
GPUParticles3D node), so any white shockwave can be recolored by duplicating the scene and changing that color. Duplicate a material to change
its noises, erosion, emission or distortion strength. Each texture slot has a "_sampling" setting (clamp U, clamp V,
sRGB) matching the texture it holds. The distortion shockwaves only bend opaque geometry (the screen texture), not other
transparent effects.
The particle settings of each effect are in the process material of its GPUParticles3D node
(Inspector > Process Material).


SUPPORT
-------
Join our Discord server: https://discord.gg/VeRbY8kMaD
Questions: info@vefects.com
More info about our products: https://vefects.com/
Instagram: https://www.instagram.com/vefects/
X / Twitter: https://twitter.com/vefects/
LinkedIn: https://www.linkedin.com/company/vefects
YouTube: https://www.youtube.com/channel/UCC8Ookxa2TOdCoKRT4wLcbA/videos

Have fun! :)
