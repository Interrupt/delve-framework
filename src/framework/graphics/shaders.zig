const std = @import("std");
const yaml = @import("zigyaml");
const mem = @import("../mem.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");

const ShaderYamlError = error{
    Parse,
    BackendNotFound,
};

pub const ShaderInfo = struct {
    shader_def: ShaderDefinition,
    vs_source: [:0]const u8 = undefined,
    fs_source: [:0]const u8 = undefined,
};

pub fn loadFromYaml(file_path: []const u8) !?graphics.Shader {
    var arena = std.heap.ArenaAllocator.init(mem.getAllocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = try parseYamlShader(allocator, file_path);
    var shader_info: ShaderInfo = .{ .shader_def = result };

    // debug output!
    for (result.programs) |program| {
        debug.log("Found shader def: {s}: {s}", .{ result.slang, program.name });

        // debug.log("  vs: {s}", .{program.vs.path});
        // for (program.vs.uniform_blocks) |block| {
        //     debug.log("    uniform: {s} - {d}", .{ block.struct_name, block.size });
        //     for (block.uniforms) |*uniform| {
        //         debug.log("      var: {s}: {s} x {d}", .{ uniform.name, uniform.type, uniform.array_count });
        //     }
        // }
        // debug.log("  fs: {s}", .{program.fs.path});
        // for (program.fs.uniform_blocks) |block| {
        //     debug.log("    uniform: {s} - {d}", .{ block.struct_name, block.size });
        //     for (block.uniforms) |*uniform| {
        //         debug.log("      var: {s}: {s} x {d}", .{ uniform.name, uniform.type, uniform.array_count });
        //     }
        // }

        shader_info.vs_source = try loadShaderSource(allocator, program.vs.path);
        shader_info.fs_source = try loadShaderSource(allocator, program.fs.path);
        break;
    }

    return graphics.Shader.initFromShaderInfo(shader_info);
}

fn loadShaderSource(allocator: std.mem.Allocator, shader_path: []const u8) ![:0]const u8 {
    const file = try std.fs.cwd().openFile(shader_path, .{});
    defer file.close();

    const source: [:0]const u8 = try file.readToEndAllocOptions(allocator, std.math.maxInt(u32), null, @alignOf(u8), 0);
    return source;
}

pub fn parseYamlShader(allocator: std.mem.Allocator, file_path: []const u8) !ShaderDefinition {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u32));

    var untyped_yaml = yaml.Yaml.load(allocator, source) catch |e| {
        debug.log("Yaml loading error! {any}", .{e});
        return e;
    };

    const result = untyped_yaml.parse(ShaderYaml) catch |e| {
        debug.log("Yaml parsing error! {any}", .{e});
        return e;
    };

    // find the shader that matches our graphics backend
    for (result.shaders) |shader| {
        // HACK: just look for Metal shaders for now!
        if (std.mem.eql(u8, shader.slang, "metal_macos"))
            return shader;
    }

    return ShaderYamlError.BackendNotFound;
}

pub const ShaderYaml = struct {
    shaders: []ShaderDefinition,
};

pub const ShaderDefinition = struct {
    slang: []const u8,
    programs: []ShaderProgram,
};

pub const ShaderProgram = struct {
    name: []const u8,
    vs: ShaderProgramDefinition,
    fs: ShaderProgramDefinition,
};

pub const ShaderProgramDefinition = struct {
    path: []const u8,
    is_binary: []const u8, // bool crashes?
    entry_point: []const u8,
    inputs: ?[]ShaderSlot,
    outputs: ?[]ShaderSlot,
    uniform_blocks: ?[]UniformBlocks,
    images: ?[]ShaderImage,
    samplers: ?[]ShaderSampler,
    image_sampler_pairs: ?[]ShaderSamplerPairs,
};

pub const ShaderSlot = struct {
    slot: u32,
    name: []const u8,
    sem_name: []const u8,
    sem_index: u32,
};

pub const UniformBlocks = struct {
    slot: u32,
    size: u32,
    struct_name: []const u8,
    inst_name: []const u8,
    uniforms: []ShaderUniform,
};

pub const ShaderUniform = struct {
    name: []const u8,
    type: []const u8,
    array_count: i32,
    offset: i32,
};

// todo
pub const ShaderImage = struct {
    slot: u32,
    name: []const u8,
    multisampled: []const u8,
    type: []const u8,
    sample_type: []const u8,
};

pub const ShaderSampler = struct {
    slot: u32,
    name: []const u8,
    sampler_type: []const u8,
};

pub const ShaderSamplerPairs = struct {
    slot: u32,
    name: []const u8,
    image_name: []const u8,
    sampler_name: []const u8,
};

// pub fn testYaml() !void {
//     var untyped = yaml.Yaml.load(mem.getAllocator(), "testentry: chad 2") catch |e| {
//         debug.log("Yaml loading error! {any}", .{e});
//         return;
//     };
//     defer untyped.deinit();
//
//     // var untyped = try yaml_parsed.load(YamlTest);
//     // defer untyped.deinit();
//
//     debug.log("Yaml: {s}", .{untyped.docs.items[0].map.get("testentry").?.string});
// }
