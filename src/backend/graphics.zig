const debug = @import("../debug.zig");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

const shaders = @import("../shaders/texcube.glsl.zig");

const vec3 = @import("../math.zig").Vec3;
const mat4 = @import("../math.zig").Mat4;

const debugtext = sokol.debugtext;

// TODO: Where should the math library stuff live?
// Look into using a third party math.zig instead of sokol's
// A vertex struct with position, color and uv-coords
const Vertex = extern struct { x: f32, y: f32, z: f32, color: u32, u: i16, v: i16 };

pub const Vector2 = struct {
    x: f32,
    y: f32,
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,
};

const state = struct {
    var debug_draw_bindings: sg.Bindings = .{};
    var debug_draw_pipeline: sg.Pipeline = .{};

    var bindings: sg.Bindings = .{};
    var pipeline: sg.Pipeline = .{};

    var view: mat4 = mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, vec3.zero(), vec3.up());
};

var default_pass_action: sg.PassAction = .{};

pub fn init() !void {
    debug.log("Graphics subsystem starting", .{});

    // Setup debug text rendering
    var text_desc: debugtext.Desc = .{
        .logger = .{ .func = slog.func },
    };
    text_desc.fonts[0] = debugtext.fontOric();
    debugtext.setup(text_desc);

    default_pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 1 },
    };

    // create vertex buffer with triangle vertices
    state.bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]Vertex{
            .{ .x = 0.0, .y = 0.5, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 0 },
            .{ .x = 0.5, .y = -0.5, .z = 0.0, .color = 0xFFFFFFFF, .u = 32767, .v = 0 },
            .{ .x = -0.5, .y = -0.5, .z = 0.0, .color = 0xFF111111, .u = 32767, .v = 32767 },
        }),
    });

    // create vertex buffer with debug quad vertices
    state.debug_draw_bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]Vertex{
            .{ .x = 0.0, .y = 1.0, .z = 0.0, .color = 0xFF111111, .u = 0, .v = 0 },
            .{ .x = 1.0, .y = 1.0, .z = 0.0, .color = 0xFF111111, .u = 6550, .v = 0 },
            .{ .x = 1.0, .y = 0.0, .z = 0.0, .color = 0xFF111111, .u = 6550, .v = 6550},
            .{ .x = 0.0, .y = 0.0, .z = 0.0, .color = 0xFF111111, .u = 0, .v = 6550},
        }),
    });

    // debug quad index buffer
    state.debug_draw_bindings.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
    });

    // create a small debug checker-board texture
    var img_desc: sg.ImageDesc = .{
        .width = 4,
        .height = 4,
    };
    img_desc.data.subimage[0][0] = sg.asRange(&[4 * 4]u32{
        0xFFFFFFFF, 0xFFFF0000, 0xFFFFFFFF, 0xFF000000,
        0xFF000000, 0xFFFFFFFF, 0xFF00FF00, 0xFFFFFFFF,
        0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, 0xFF0000FF,
        0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
    });
    state.bindings.fs.images[shaders.SLOT_tex] = sg.makeImage(img_desc);
    state.debug_draw_bindings.fs.images[shaders.SLOT_tex] = sg.makeImage(img_desc);

    // ...and a sampler object with default attributes
    state.bindings.fs.samplers[shaders.SLOT_smp] = sg.makeSampler(.{});
    state.debug_draw_bindings.fs.samplers[shaders.SLOT_smp] = sg.makeSampler(.{});

    // create a shader and pipeline object
    const shader = sg.makeShader(shaders.texcubeShaderDesc(sg.queryBackend()));
    var pipe_desc: sg.PipelineDesc = .{
        .shader = shader,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        }
    };
    pipe_desc.layout.attrs[shaders.ATTR_vs_pos].format = .FLOAT3;
    pipe_desc.layout.attrs[shaders.ATTR_vs_color0].format = .UBYTE4N;
    pipe_desc.layout.attrs[shaders.ATTR_vs_texcoord0].format = .SHORT2N;
    state.pipeline = sg.makePipeline(pipe_desc);

    pipe_desc.index_type = .UINT16;
    pipe_desc.depth= .{};
    state.debug_draw_pipeline = sg.makePipeline(pipe_desc);

    debug.log("Graphics subsystem started successfully", .{});
}

pub fn deinit() void {
    debug.log("Graphics subsystem stopping", .{});
}

var rotx: f32 = 0.0;
var roty: f32 = 0.0;

pub fn startFrame() void {
    rotx += 0.1;
    roty += 0.5;

    // reset debug text
    debugtext.canvas(sapp.widthf() * 0.5, sapp.heightf() * 0.5);
    debugtext.layer(0);

    // setup view state
    state.view = mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, vec3.zero(), vec3.up());
    const vs_params = computeVsParams(rotx, roty);

    sg.beginDefaultPass(default_pass_action, sapp.width(), sapp.height());

    sg.applyPipeline(state.pipeline);
    sg.applyBindings(state.bindings);

    sg.applyUniforms(.VS, shaders.SLOT_vs_params, sg.asRange(&vs_params));

    sg.draw(0, 3, 1);
}

pub fn endFrame() void {

    // draw console text on a new layer
    debugtext.layer(1);
    debug.drawConsole(false);

    // draw any debug text
    debugtext.drawLayer(0);

    // draw the console text over other text
    debug.drawConsoleBackground();
    debugtext.drawLayer(1);

    // drawDebugRectangle(0.0, 0.0, 640.0, 480.0);

    sg.endPass();
    sg.commit();
}

pub fn clear(color: Color) void {
    _ = color;
}

pub fn line(start: Vector2, end: Vector2, color: Color) void {
    // _ = start;
    // _ = end;
    _ = color;

    const translateVec3: vec3 = vec3{.x = -3.5 + end.x * 0.01, .y = 2.5 + end.y * -0.01, .z = 0.0};

    // Move the view state!
    state.view = mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, vec3.zero(), vec3.up());
    state.view = mat4.mul(state.view, mat4.translate(translateVec3));
    const vs_params = computeVsParams(start.x, start.y);

    sg.applyUniforms(.VS, shaders.SLOT_vs_params, sg.asRange(&vs_params));
    sg.draw(0, 3, 1);
}

fn makeDefaultShaderDesc() sg.ShaderDesc {
    var desc: sg.ShaderDesc = .{};
    switch (sg.queryBackend()) {
        .D3D11 => {
            desc.attrs[0].sem_name = "POS";
            desc.attrs[1].sem_name = "COLOR";
            desc.vs.source =
                \\struct vs_in {
                \\  float4 pos: POS;
                \\  float4 color: COLOR;
                \\};
                \\struct vs_out {
                \\  float4 color: COLOR0;
                \\  float4 pos: SV_Position;
                \\};
                \\vs_out main(vs_in inp) {
                \\  vs_out outp;
                \\  outp.pos = inp.pos;
                \\  outp.color = inp.color;
                \\  return outp;
                \\}
            ;
            desc.fs.source =
                \\float4 main(float4 color: COLOR0): SV_Target0 {
                \\  return color;
                \\}
            ;
        },
        .GLCORE33 => {
            desc.attrs[0].name = "position";
            desc.attrs[1].name = "color0";
            desc.vs.source =
                \\ #version 330
                \\ in vec4 position;
                \\ in vec4 color0;
                \\ out vec4 color;
                \\ void main() {
                \\   gl_Position = position;
                \\   color = color0;
                \\ }
            ;
            desc.fs.source =
                \\ #version 330
                \\ in vec4 color;
                \\ out vec4 frag_color;
                \\ void main() {
                \\   frag_color = color;
                \\ }
            ;
        },
        .METAL_MACOS => {
            desc.vs.source =
                \\ #include <metal_stdlib>
                \\ using namespace metal;
                \\ struct vs_in {
                \\   float4 position [[attribute(0)]];
                \\   float4 color [[attribute(1)]];
                \\ };
                \\ struct vs_out {
                \\   float4 position [[position]];
                \\   float4 color;
                \\ };
                \\ vertex vs_out _main(vs_in inp [[stage_in]]) {
                \\   vs_out outp;
                \\   outp.position = inp.position;
                \\   outp.color = inp.color;
                \\   return outp;
                \\ }
            ;
            desc.fs.source =
                \\ #include <metal_stdlib>
                \\ using namespace metal;
                \\ fragment float4 _main(float4 color [[stage_in]]) {
                \\   return color;
                \\ };
            ;
        },
        else => {},
    }
    return desc;
}

fn computeVsParams(rx: f32, ry: f32) shaders.VsParams {
    const rxm = mat4.rotate(rx, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    const rym = mat4.rotate(ry, .{ .x = 0.0, .y = 1.0, .z = 0.0 });
    const model = mat4.mul(rxm, rym);
    const aspect = sapp.widthf() / sapp.heightf();
    const proj = mat4.persp(60.0, aspect, 0.01, 10.0);
    return shaders.VsParams{ .mvp = mat4.mul(mat4.mul(proj, state.view), model) };
}

fn computeOrthoVsParams() shaders.VsParams {
    const model = mat4.identity();
    const proj = mat4.ortho(0.0, sapp.widthf(), 0.0, sapp.heightf(), -5.0, 5.0);
    return shaders.VsParams{ .mvp = mat4.mul(mat4.mul(proj, state.view), model) };
}

pub fn setDebugTextColor4f(r: f32, g: f32, b: f32, a: f32) void {
    debugtext.color4f(r, g, b, a);
}

pub fn setDebugTextColor4b(r: u8, g: u8, b: u8, a: u8) void {
    debugtext.color4b(r, g, b, a);
}

pub fn drawDebugText(x: f32, y: f32, str: [:0]const u8) void {
    debugtext.pos(x * 0.125, y * 0.125);
    debugtext.puts(str);
}

pub fn drawDebugTextChar(x: f32, y: f32, char: u8) void {
    debugtext.pos(x * 0.125, y * 0.125);
    debugtext.putc(char);
}

pub fn drawDebugRectangle(x: f32, y: f32, width: f32, height: f32) void {
    // setup view state
    const translateVec3: vec3 = vec3{.x = x, .y = @as(f32, @floatFromInt(getDisplayHeight())) - (y + height), .z = 0.0};
    const scaleVec3: vec3 = vec3{.x = width, .y = height, .z = 1.0};
    state.view = mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 0.5 }, vec3.zero(), vec3.up());
    state.view = mat4.mul(state.view, mat4.translate(translateVec3));
    state.view = mat4.mul(state.view, mat4.scale(scaleVec3));
    const vs_params = computeOrthoVsParams();

    // set the debug draw bindings
    sg.applyPipeline(state.debug_draw_pipeline);
    sg.applyBindings(state.debug_draw_bindings);
    sg.applyUniforms(.VS, shaders.SLOT_vs_params, sg.asRange(&vs_params));

    // draw our quad
    sg.draw(0, 6, 1);
}

pub fn getDisplayWidth() i32 {
   return sapp.width();
}

pub fn getDisplayHeight() i32 {
   return sapp.height();
}

pub fn getDisplayDPIScale() f32 {
    return sapp.dpiScale();
}
