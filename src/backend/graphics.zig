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
    state.bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]f32{
            // positions         colors
            0.0,  0.5,  0.5, 1.0, 0.0, 0.0, 1.0,
            0.5,  -0.5, 0.5, 0.0, 1.0, 0.0, 1.0,
            -0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0,
        }),
    });

    // create a vertex buffer that can be updated
    // state.bindings.vertex_buffers[0] = sg.makeBuffer(.{
    //     .usage = .STREAM,
    //     .size = 3 * 7 * @sizeOf(f32),
    // });

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

    // sg.updateBuffer(state.bindings.vertex_buffers[0], sg.asRange(&[_]f32{
    //         // positions         colors
    //         0.0 + drawx_offset,  0.5,  0.5, 1.0, 0.0, 0.0, 1.0,
    //         0.5 + drawx_offset,  -0.5, 0.5, 0.0, 1.0, 0.0, 1.0,
    //         -0.5 + drawx_offset, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0,
    //     })
    // );

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
}

pub fn line(start: Vector2, end: Vector2, color: Color) void {
    _ = start;
    // _ = end;
    _ = color;

    const size: f32 = 0.1;
    var x_offset: f32 = -1.0;
    var y_offset: f32 = 1.0;
    x_offset += end.x * (1.0 / 640.0) * 2;
    y_offset -= end.y * (1.0 / 480.0) * 2;

    sg.destroyBuffer(state.bindings.vertex_buffers[0]);

    state.bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]f32{
            // positions         colors
            x_offset, y_offset + size, 0.5, 1.0, 0.0, 0.0, 1.0,
            x_offset + size, y_offset - size, 0.5, 0.0, 1.0, 0.0, 1.0,
            x_offset - size, y_offset - size, 0.5, 0.0, 0.0, 1.0, 1.0,
        }),
    });

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
