# Delve Framework

Delve is a simple framework for building games written in Zig using Lua for scripting. Currently updated to `Zig 0.12.0-dev.2063+804cee3b9`

*This is in early development and the api is still coming together, so be warned!*

<p align="center">
<img width="1072" alt="Screen Shot 2024-01-27 at 12 02 33 AM" src="https://github.com/Interrupt/delve-framework/assets/1374/45b64806-7829-4542-80d5-5a892eebf80d">
</p>


## Design Philosphy

Delve uses Zig to make writing cross platform games easy, and because it is easy to interop with the vast library of existing C/C++ game development libraries. Its main goal is to be as cross platform and unopinionated as much as possible, making it easy to switch out implementations as needed.

## Libraries Used

* Sokol for cross platform graphics and input
* Lua for scripting using ziglua
* stb_image for loading images
* zaudio and zmesh from zig-gamedev

## Scripting

The scripting manager can generate bindings for Lua automatically by reflecting on a zig file. Example:

```
// Find all public functions in `api/graphics.zig` and make them available to Lua under the module name `graphics`
bindZigLibrary("graphics", @import("api/graphics.zig"));
```

Delve will use the `assets/main.lua` Lua file for scripting unless given a new path on the command line during startup.

## 2D and 3D rendering

Rendering uses the Sokol framework to use modern, cross platform graphics APIs. Supports Vulkan, Metal, DirectX 11/12, OpenGL 3/ES, and WebGPU.

Batched 2d shape rendering:

![delve-framework-2](https://github.com/Interrupt/delve-framework/assets/1374/48665a57-ba2b-44c2-a520-39b885c42de1)

GLTF mesh rendering:

![delve-framework-8](https://github.com/Interrupt/delve-framework/assets/1374/215754b4-f186-419a-842e-cb38a4e2c88f)




## Modules, all the way down

In the Delve framework most everything is a module, so that applications can use just the functionality they want as well as extending the framework as needed. As an example, the scripting layer is a module that registers other modules.

Additional Zig code can be registered as a Module to run during the game lifecycle:

```
const exampleModule = modules.Module {
    .name = "example-module",
    .init_fn = my_on_init,
    .tick_fn = my_on_tick,
    .draw_fn = my_on_draw,
    .cleanup_fn = my_on_cleanup,
};

try modules.registerModule(exampleModule);
```

Some example modules are included automatically to exercise some code paths, these live under `src/examples` and are good examples of how to start using the framework.

* [Sprite Animation Example](src/examples/sprite-animation.zig)
* [Mesh Drawing Example](src/examples/meshes.zig)
* [Debug Drawing Example](src/examples/debugdraw.zig)

## Building the examples

- Add dependency repository link

`build.zig.zon`
```
.{
    .name = "my_project",
    .version = "0.0.1",
    .dependencies = .{
        .delve = .{
            .url = "git+https://github.com/Interrupt/delve-framework/tree/0.12.x.git#___COMMIT_HASH___",
            // add compilers suggested line about .hash
        },
    },
}
```
- Link dependency module
`build.zig`
```
    const delve = b.dependency("delve", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("delve", delve.module("delve"));
```



- Just build
```java
zig build run
```

### Build and run an examples
```
zig build run-audio
zig build run-clear
zig build run-collision
zig build run-debugdraw
zig build run-easing
zig build run-forest
zig build run-framepacing
zig build run-lua
zig build run-meshbuilder
zig build run-meshes
zig build run-passes
zig build run-sprite-animation
zig build run-sprites
zig build run-stresstest
```

### Set optimization

```java
zig build -Doptimize=ReleaseSafe run-forest
zig build -Doptimize=ReleaseSmall run-forest
```
