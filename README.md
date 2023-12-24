# Delve Framework

Delve is framework for building games written in Zig using Lua for scripting.

## Design Philosphy

Delve uses Zig to make writing cross platform games easy, and because it is easy to interop with the vast library of existing C/C++ game development libraries.

## Libraries Used

* Sokol for cross platform graphics and input
* Lua for scripting
* stb_image for loading images

## Scripting

The scripting manager can generate bindings for Lua automatically by reflecting on a zig file. Example:

```
// Find all public functions in `api/graphics.zig` and make them available to Lua under the module name `graphics`
bindZigLibrary("graphics", @import("api/graphics.zig"));
```

## Modules

Additional Zig code can be registered as a Module to run during the game lifecycle:

```
const exampleModule = modules.Module {
    .init_fn = my_on_init,
    .tick_fn = my_on_tick,
    .draw_fn = my_on_draw,
    .cleanup_fn = my_on_cleanup,
};

try modules.registerModule(exampleModule);
```

Some example modules are included automatically to exercise some code paths, these live under `src/examples`
