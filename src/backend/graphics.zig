const debug = @import("../debug.zig");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

pub const Vector2 = struct {
    x: f32,
    y: f32,
};

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,
};

const state = struct {
    var bindings: sg.Bindings = .{};
    var pipeline: sg.Pipeline = .{};
};

var default_pass_action: sg.PassAction = .{};

pub fn init() !void {
    debug.log("Graphics subsystem starting", .{});

    default_pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.15, .g = 0.15, .b = 0.15, .a = 1 },
    };

    // create vertex buffer with triangle vertices
    // state.bindings.vertex_buffers[0] = sg.makeBuffer(.{
    //     .data = sg.asRange(&[_]f32{
    //         // positions         colors
    //         0.0,  0.5,  0.5, 1.0, 0.0, 0.0, 1.0,
    //         0.5,  -0.5, 0.5, 0.0, 1.0, 0.0, 1.0,
    //         -0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0,
    //     }),
    // });

    // create a vertex buffer that can be updated
    state.bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .usage = .STREAM,
        .size = 3 * 7 * @sizeOf(f32),
    });

    // create a shader and pipeline object
    const shader = sg.makeShader(makeDefaultShaderDesc());
    var pipe_desc: sg.PipelineDesc = .{ .shader = shader };
    pipe_desc.layout.attrs[0].format = .FLOAT3;
    pipe_desc.layout.attrs[1].format = .FLOAT4;
    state.pipeline = sg.makePipeline(pipe_desc);
}

pub fn deinit() void {
    debug.log("Graphics subsystem stopping", .{});
}

var drawx_offset: f32 = 0.0;

pub fn startFrame() void {
    drawx_offset += 0.001;

    sg.updateBuffer(state.bindings.vertex_buffers[0], sg.asRange(&[_]f32{
            // positions         colors
            0.0 + drawx_offset,  0.5,  0.5, 1.0, 0.0, 0.0, 1.0,
            0.5 + drawx_offset,  -0.5, 0.5, 0.0, 1.0, 0.0, 1.0,
            -0.5 + drawx_offset, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0,
        })
    );

    sg.beginDefaultPass(default_pass_action, sapp.width(), sapp.height());

    sg.applyPipeline(state.pipeline);
    sg.applyBindings(state.bindings);

    sg.draw(0, 3, 1);
}

pub fn endFrame() void {
    debug.drawConsole();
    sg.endPass();
    sg.commit();

}

pub fn clear(color: Color) void {
    _ = color;

    // clear_pass_action.colors[0].clear_value.r = color.r;
    // clear_pass_action.colors[0].clear_value.g = color.g;
    // clear_pass_action.colors[0].clear_value.b = color.b;
    // clear_pass_action.colors[0].clear_value.a = 1.0;

    // sg.beginDefaultPass(clear_pass_action, sapp.width(), sapp.height());
    // sg.endPass();
    // sg.commit();
}

pub fn line(start: Vector2, end: Vector2, color: Color) void {
    _ = start;
    _ = end;
    _ = color;

    // sg.draw(0, 3, 1);

    // const renderer = zigsdl.getRenderer();
    // _ = sdl.SDL_SetRenderDrawColor(renderer, @intFromFloat(color.r), @intFromFloat(color.g), @intFromFloat(color.b), 0xFF);
    // _ = sdl.SDL_RenderDrawLine(renderer, @intFromFloat(start.x), @intFromFloat(start.y), @intFromFloat(end.x), @intFromFloat(end.y));
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
