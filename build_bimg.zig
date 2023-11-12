const std = @import("std");
const bx = @import("build_bx.zig");
const bimg_path = "3rdparty/bimg/";

pub fn link(exe: *std.build.LibExeObjStep) void {
    const lib = buildLibrary(exe);
    addBimgIncludes(exe);
    exe.linkLibrary(lib);
}

fn buildLibrary(exe: *std.build.LibExeObjStep) *std.build.LibExeObjStep {

      const cxx_options = [_][]const u8{
        "-fno-strict-aliasing",
        "-fno-exceptions",
        "-fno-rtti",
        "-ffast-math",
        "-DBX_CONFIG_DEBUG",
    };

    const bimg_lib = exe.step.owner.addStaticLibrary(.{ .name = "bimg", .target = exe.target, .optimize = exe.optimize});
    addBimgIncludes(bimg_lib);
    bimg_lib.addIncludePath(.{ .path = bimg_path ++ "3rdparty/"});
    bimg_lib.addIncludePath(.{ .path = bimg_path ++ "3rdparty/astc-encoder/"});
    bimg_lib.addIncludePath(.{ .path = bimg_path ++ "3rdparty/astc-encoder/include/"});
    bimg_lib.addCSourceFiles(&.{
        bimg_path ++ "src/image.cpp",
        bimg_path ++ "src/image_gnf.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_averages_and_directions.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_block_sizes.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_color_quantize.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_color_unquantize.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_compress_symbolic.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_compute_variance.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_decompress_symbolic.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_diagnostic_trace.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_entry.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_find_best_partitioning.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_ideal_endpoints_and_weights.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_image.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_integer_sequence.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_mathlib.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_mathlib_softfloat.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_partition_tables.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_percentile_tables.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_pick_best_endpoint_format.cpp",
        // bimg_path ++ "3rdparty/astc-encoder/source/astcenc_platform_isa_detection.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_quantization.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_symbolic_physical.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_weight_align.cpp",
        bimg_path ++ "3rdparty/astc-encoder/source/astcenc_weight_quant_xfer_tables.cpp",
    }, &cxx_options);
    bimg_lib.want_lto = false;
    bimg_lib.linkSystemLibrary("c");
    bimg_lib.linkSystemLibrary("c++");
    bx.link(bimg_lib);

    const bimg_lib_artifact = exe.step.owner.addInstallArtifact(bimg_lib, .{});
    exe.step.owner.getInstallStep().dependOn(&bimg_lib_artifact.step);

    return bimg_lib;
}

fn addBimgIncludes(exe: *std.build.LibExeObjStep) void {
    exe.addIncludePath(.{ .path = thisDir() ++ "/" ++ bimg_path ++ "include/"});
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
