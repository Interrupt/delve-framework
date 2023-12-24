const debug = @import("../debug.zig");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

const shaders = @import("../graphics/shaders/texcube.glsl.zig");

const images = @import("../images.zig");

const vec3 = @import("../math.zig").Vec3;
const mat4 = @import("../math.zig").Mat4;

const debugtext = sokol.debugtext;

pub const test_asset = @embedFile("../static/test.gif");

// TODO: Where should the math library stuff live?
// Foster puts everything in places like /Spatial or /Graphics
// Look into using a third party math.zig instead of sokol's
// A vertex struct with position, color and uv-coords
// TODO: Stop using packed color and uvs!

pub const Vertex = extern struct { x: f32, y: f32, z: f32, color: u32, u: i16, v: i16 };

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

// TODO: This should be an interface!
// pub const Bindings = struct {
//     create: fn (vertices: []Vertex, indices: []u16) void,
//     bind: fn () void,
// };

pub const BindingConfig = struct {
    updatable: bool = false,
    vert_len: usize = 3200,
    index_len: usize = 3200,
};

pub const Bindings = struct {
    length: usize,
    sokol_bindings: ?sg.Bindings,

    pub fn init(cfg: BindingConfig) Bindings {
        var bindings: Bindings = Bindings {
            .length = 0,
            .sokol_bindings = .{},
        };

        // Updatable buffers will need to be created ahead-of-time
        if(cfg.updatable) {
            bindings.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
                .usage = .STREAM,
                .size = cfg.vert_len * @sizeOf(Vertex),
            });
            bindings.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
                .usage = .STREAM,
                .type = .INDEXBUFFER,
                .size = cfg.index_len * @sizeOf(u16),
            });
        }

        return bindings;
    }

    /// Creates new buffers to hold these vertices and indices
    pub fn set(self: *Bindings, vertices: anytype, indices: anytype, length: usize) void {
        if(self.sokol_bindings == null) {
            return;
        }

        self.length = length;
        self.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
            .data = sg.asRange(vertices),
        });
        self.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sg.asRange(indices),
        });
    }

    /// Updates the existing buffers with new data
    pub fn update(self: *Bindings, vertices: anytype, indices: anytype, vert_len: usize, index_len: usize) void {
        if(self.sokol_bindings == null) {
            return;
        }

        self.length = index_len;

        if(index_len == 0)
            return;

        sg.updateBuffer(self.sokol_bindings.?.vertex_buffers[0], sg.asRange(vertices[0..vert_len]));
        sg.updateBuffer(self.sokol_bindings.?.index_buffer, sg.asRange(indices[0..index_len]));
    }

    pub fn setTexture(self: *Bindings, texture: Texture) void {
        if(texture.sokol_image == null)
            return;

        self.sokol_bindings.?.fs.images[shaders.SLOT_tex] = texture.sokol_image.?;
        self.sokol_bindings.?.fs.samplers[shaders.SLOT_smp] = sg.makeSampler(.{});
    }

    pub fn destroy(self: *Bindings) void {
        _ = self;
    }
};

pub const ShaderConfig = struct {
    // TODO: Put depth, index type, attributes, etc, here
};

pub const Shader = struct {
    sokol_pipeline: ?sg.Pipeline,

    pub fn init(cfg: ShaderConfig) Shader {
        _ = cfg;

        // Just use the default shader for now. Maybe use an enum to switch between builtin shaders?
        const shader = sg.makeShader(shaders.texcubeShaderDesc(sg.queryBackend()));

        var pipe_desc: sg.PipelineDesc = .{
            .index_type = .UINT16,
            .shader = shader,
            .depth = .{
                .compare = .LESS_EQUAL,
                .write_enabled = true,
            }
        };

        // todo: get these from the ShaderConfig, use intermediate enums
        pipe_desc.layout.attrs[shaders.ATTR_vs_pos].format = .FLOAT3;
        pipe_desc.layout.attrs[shaders.ATTR_vs_color0].format = .UBYTE4N;
        pipe_desc.layout.attrs[shaders.ATTR_vs_texcoord0].format = .SHORT2N;

        return Shader { .sokol_pipeline = sg.makePipeline(pipe_desc) };
    }
};

pub const Texture = struct {
    width: u32,
    height: u32,
    sokol_image: ?sg.Image,

    pub fn init(image: *images.Image) Texture {
        var img_desc: sg.ImageDesc = .{
            .width = image.width,
            .height = image.height,
            .pixel_format = .RGBA8,
        };

        img_desc.data.subimage[0][0] = sg.asRange(image.raw);

        return Texture {
            .width = image.width,
            .height = image.height,
            .sokol_image = sg.makeImage(img_desc),
        };
    }

    pub fn initFromBytes(width: u32, height: u32, image_bytes: anytype) Texture {
        var img_desc: sg.ImageDesc = .{
            .width = @intCast(width),
            .height = @intCast(height),
            .pixel_format = .RGBA8,
        };

        img_desc.data.subimage[0][0] = sg.asRange(image_bytes);

        return Texture {
            .width = width,
            .height = height,
            .sokol_image = sg.makeImage(img_desc),
        };
    }
};

const state = struct {
    var debug_draw_bindings: sg.Bindings = .{};
    var debug_draw_pipeline: sg.Pipeline = .{};
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

    // create vertex buffer with debug quad vertices
    state.debug_draw_bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]Vertex{
            .{ .x = 0.0, .y = 1.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 0 },
            .{ .x = 1.0, .y = 1.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 6550, .v = 0 },
            .{ .x = 1.0, .y = 0.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 6550, .v = 6550},
            .{ .x = 0.0, .y = 0.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 6550},
        }),
    });

    // debug quad index buffer
    state.debug_draw_bindings.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
    });

    // Load a debug texture for testing
    var test_image = try images.loadBytes(test_asset);
    var test_img_desc: sg.ImageDesc = .{
        .width = @intCast(test_image.width),
        .height = @intCast(test_image.height),
        .pixel_format = .RGBA8,
    };
    debug.log("Loaded font image successfully: {d}x{d}\n", .{test_image.width, test_image.height});
    test_img_desc.data.subimage[0][0] = sg.asRange(test_image.raw);
    state.debug_draw_bindings.fs.images[shaders.SLOT_tex] = sg.makeImage(test_img_desc);

    // ...and a sampler object with default attributes
    state.debug_draw_bindings.fs.samplers[shaders.SLOT_smp] = sg.makeSampler(.{});

    // create a debug shader and pipeline object
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

    pipe_desc.index_type = .UINT16;
    state.debug_draw_pipeline = sg.makePipeline(pipe_desc);

    debug.log("Graphics subsystem started successfully", .{});
}

pub fn deinit() void {
    debug.log("Graphics subsystem stopping", .{});
}

var rotx: f32 = 0.0;
var roty: f32 = 0.0;

pub fn startFrame() void {
    // rotx += 0.1;
    // roty += 0.1;

    // reset debug text
    debugtext.canvas(sapp.widthf() * 0.5, sapp.heightf() * 0.5);
    debugtext.layer(0);

    // setup view state
    state.view = mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, vec3.zero(), vec3.up());

    sg.beginDefaultPass(default_pass_action, sapp.width(), sapp.height());
}

pub fn endFrame() void {

    // test texture drawing
    drawDebugRectangle(50.0, 50.0, 100.0, 100.0);

    // draw console text on a new layer
    debugtext.layer(1);
    debug.drawConsole(false);

    // draw any debug text
    debugtext.drawLayer(0);

    // draw the console text over other text
    debug.drawConsoleBackground();
    debugtext.drawLayer(1);

    sg.endPass();
    sg.commit();
}

pub fn clear(color: Color) void {
    _ = color;
}

pub fn setView(view_matrix: mat4) void {
    state.view = view_matrix;
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

    sg.applyPipeline(state.debug_draw_pipeline);
    sg.applyBindings(state.debug_draw_bindings);

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
    const proj = mat4.persp(60.0, aspect, 0.01, 50.0);
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

pub fn drawSubset(start: u32, end: u32, bindings: *Bindings, shader: *Shader) void {
    if(bindings.sokol_bindings == null or shader.sokol_pipeline == null)
        return;

    // todo: make a graphics.setView function to update the view
    const vs_params = computeVsParams(rotx, roty);

    // todo: only apply pipeline / bindings if they actually changed
    sg.applyPipeline(shader.sokol_pipeline.?);
    sg.applyBindings(bindings.sokol_bindings.?);
    sg.applyUniforms(.VS, shaders.SLOT_vs_params, sg.asRange(&vs_params));

    sg.draw(start, end, 1);
}

pub fn draw(bindings: *Bindings, shader: *Shader) void {
    // Draw the whole buffer
    drawSubset(0, @intCast(bindings.length), bindings, shader);
}
