# Delve Framework

Delve is a simple framework for building games written in Zig using Lua for scripting.

*This is in early development and the api is still coming together, so be warned!*
<img width="1072" alt="Screen Shot 2024-01-09 at 12 11 23 PM" src="https://github.com/Interrupt/delve-framework/assets/1374/b4e7f311-1cee-4463-9127-a9d69b1894d1">

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

* [Sprite Batch Example](src/examples/batcher.zig)
* [Mesh Drawing Example](src/examples/mesh.zig)
* [Debug Drawing Example](src/examples/debugdraw.zig)
