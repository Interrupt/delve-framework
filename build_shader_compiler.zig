const std = @import("std");

const bx = @import("build_bx.zig");
const bimg = @import("build_bimg.zig");
const bgfx = @import("build_bgfx.zig");

const LibExeObjStep = std.build.LibExeObjStep;
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Pkg = std.build.Pkg;

pub fn build(b: *Builder, target: std.zig.CrossTarget, build_mode: std.builtin.Mode) *std.build.LibExeObjStep {
    // fcpp
    const fcpp_cxx_options = [_][]const u8{
        "-D__STDC_LIMIT_MACROS",
        "-D__STDC_FORMAT_MACROS",
        "-D__STDC_CONSTANT_MACROS",
        "-DNINCLUDE=64",
        "-DNWORK=65536",
        "-DNBUFF=65536",
        "-DOLD_PREPROCESSOR=0",
        "-fno-sanitize=undefined",
    };

    const fcpp_path = "3rdparty/bgfx/3rdparty/fcpp/";
    const fcpp_lib = b.addStaticLibrary(.{ .name = "fcpp", .target = target, .optimize = build_mode});

    fcpp_lib.addIncludePath(.{ .path = fcpp_path});
    fcpp_lib.addCSourceFiles(&.{
        fcpp_path ++ "cpp1.c",
        fcpp_path ++ "cpp2.c",
        fcpp_path ++ "cpp3.c",
        fcpp_path ++ "cpp4.c",
        fcpp_path ++ "cpp5.c",
        fcpp_path ++ "cpp6.c",
    }, &fcpp_cxx_options);

    fcpp_lib.want_lto = false;
    fcpp_lib.linkSystemLibrary("c++");

    const fcpp_lib_artifact = b.addInstallArtifact(fcpp_lib, .{});
    b.getInstallStep().dependOn(&fcpp_lib_artifact.step);

    //spirv-opt
    const spirv_opt_cxx_options = [_][]const u8{
        "-D__STDC_LIMIT_MACROS",
        "-D__STDC_FORMAT_MACROS",
        "-D__STDC_CONSTANT_MACROS",
        "-fno-sanitize=undefined",
    };

    const spirv_opt_path = "3rdparty/bgfx/3rdparty/spirv-tools/";
    const spirv_opt_lib = b.addStaticLibrary(.{ .name = "spirv-opt", .target = target, .optimize = build_mode});
    spirv_opt_lib.addIncludePath(.{ .path = spirv_opt_path });
    spirv_opt_lib.addIncludePath(.{ .path = spirv_opt_path ++ "include" });
    spirv_opt_lib.addIncludePath(.{ .path = spirv_opt_path ++ "include/generated" });
    spirv_opt_lib.addIncludePath(.{ .path = spirv_opt_path ++ "source" });
    spirv_opt_lib.addIncludePath(.{ .path = "3rdparty/bgfx/3rdparty/spirv-headers/include" });

    spirv_opt_lib.addCSourceFiles(&.{
        spirv_opt_path ++ "source/assembly_grammar.cpp",
        spirv_opt_path ++ "source/binary.cpp",
        spirv_opt_path ++ "source/diagnostic.cpp",
        spirv_opt_path ++ "source/disassemble.cpp",
        spirv_opt_path ++ "source/enum_string_mapping.cpp",
        spirv_opt_path ++ "source/ext_inst.cpp",
        spirv_opt_path ++ "source/extensions.cpp",
        spirv_opt_path ++ "source/libspirv.cpp",
        spirv_opt_path ++ "source/name_mapper.cpp",
        spirv_opt_path ++ "source/opcode.cpp",
        spirv_opt_path ++ "source/operand.cpp",
        spirv_opt_path ++ "source/opt/aggressive_dead_code_elim_pass.cpp",
        spirv_opt_path ++ "source/opt/analyze_live_input_pass.cpp",
        spirv_opt_path ++ "source/opt/amd_ext_to_khr.cpp",
        spirv_opt_path ++ "source/opt/basic_block.cpp",
        spirv_opt_path ++ "source/opt/block_merge_pass.cpp",
        spirv_opt_path ++ "source/opt/block_merge_util.cpp",
        spirv_opt_path ++ "source/opt/build_module.cpp",
        spirv_opt_path ++ "source/opt/ccp_pass.cpp",
        spirv_opt_path ++ "source/opt/cfg.cpp",
        spirv_opt_path ++ "source/opt/cfg_cleanup_pass.cpp",
        spirv_opt_path ++ "source/opt/code_sink.cpp",
        spirv_opt_path ++ "source/opt/combine_access_chains.cpp",
        spirv_opt_path ++ "source/opt/compact_ids_pass.cpp",
        spirv_opt_path ++ "source/opt/composite.cpp",
        spirv_opt_path ++ "source/opt/const_folding_rules.cpp",
        spirv_opt_path ++ "source/opt/constants.cpp",
        spirv_opt_path ++ "source/opt/convert_to_half_pass.cpp",
        spirv_opt_path ++ "source/opt/convert_to_sampled_image_pass.cpp",
        spirv_opt_path ++ "source/opt/copy_prop_arrays.cpp",
        spirv_opt_path ++ "source/opt/dead_branch_elim_pass.cpp",
        spirv_opt_path ++ "source/opt/dead_insert_elim_pass.cpp",
        spirv_opt_path ++ "source/opt/dead_variable_elimination.cpp",
        spirv_opt_path ++ "source/opt/debug_info_manager.cpp",
        spirv_opt_path ++ "source/opt/decoration_manager.cpp",
        spirv_opt_path ++ "source/opt/def_use_manager.cpp",
        spirv_opt_path ++ "source/opt/desc_sroa.cpp",
        spirv_opt_path ++ "source/opt/desc_sroa_util.cpp",
        spirv_opt_path ++ "source/opt/dominator_analysis.cpp",
        spirv_opt_path ++ "source/opt/dominator_tree.cpp",
        spirv_opt_path ++ "source/opt/eliminate_dead_constant_pass.cpp",
        spirv_opt_path ++ "source/opt/eliminate_dead_functions_pass.cpp",
        spirv_opt_path ++ "source/opt/eliminate_dead_functions_util.cpp",
        spirv_opt_path ++ "source/opt/eliminate_dead_io_components_pass.cpp",
        spirv_opt_path ++ "source/opt/eliminate_dead_members_pass.cpp",
        spirv_opt_path ++ "source/opt/eliminate_dead_output_stores_pass.cpp",
        spirv_opt_path ++ "source/opt/feature_manager.cpp",
        spirv_opt_path ++ "source/opt/fix_func_call_arguments.cpp",
        spirv_opt_path ++ "source/opt/fix_storage_class.cpp",
        spirv_opt_path ++ "source/opt/flatten_decoration_pass.cpp",
        spirv_opt_path ++ "source/opt/fold.cpp",
        spirv_opt_path ++ "source/opt/fold_spec_constant_op_and_composite_pass.cpp",
        spirv_opt_path ++ "source/opt/folding_rules.cpp",
        spirv_opt_path ++ "source/opt/freeze_spec_constant_value_pass.cpp",
        spirv_opt_path ++ "source/opt/function.cpp",
        spirv_opt_path ++ "source/opt/graphics_robust_access_pass.cpp",
        spirv_opt_path ++ "source/opt/if_conversion.cpp",
        spirv_opt_path ++ "source/opt/inline_exhaustive_pass.cpp",
        spirv_opt_path ++ "source/opt/inline_opaque_pass.cpp",
        spirv_opt_path ++ "source/opt/inline_pass.cpp",
        spirv_opt_path ++ "source/opt/inst_bindless_check_pass.cpp",
        spirv_opt_path ++ "source/opt/inst_buff_addr_check_pass.cpp",
        spirv_opt_path ++ "source/opt/inst_debug_printf_pass.cpp",
        spirv_opt_path ++ "source/opt/instruction.cpp",
        spirv_opt_path ++ "source/opt/instruction_list.cpp",
        spirv_opt_path ++ "source/opt/instrument_pass.cpp",
        spirv_opt_path ++ "source/opt/interface_var_sroa.cpp",
        spirv_opt_path ++ "source/opt/ir_context.cpp",
        spirv_opt_path ++ "source/opt/ir_loader.cpp",
        spirv_opt_path ++ "source/opt/licm_pass.cpp",
        spirv_opt_path ++ "source/opt/liveness.cpp",
        spirv_opt_path ++ "source/opt/local_access_chain_convert_pass.cpp",
        spirv_opt_path ++ "source/opt/local_redundancy_elimination.cpp",
        spirv_opt_path ++ "source/opt/local_single_block_elim_pass.cpp",
        spirv_opt_path ++ "source/opt/local_single_store_elim_pass.cpp",
        spirv_opt_path ++ "source/opt/loop_dependence.cpp",
        spirv_opt_path ++ "source/opt/loop_dependence_helpers.cpp",
        spirv_opt_path ++ "source/opt/loop_descriptor.cpp",
        spirv_opt_path ++ "source/opt/loop_fission.cpp",
        spirv_opt_path ++ "source/opt/loop_fusion.cpp",
        spirv_opt_path ++ "source/opt/loop_fusion_pass.cpp",
        spirv_opt_path ++ "source/opt/loop_peeling.cpp",
        spirv_opt_path ++ "source/opt/loop_unroller.cpp",
        spirv_opt_path ++ "source/opt/loop_unswitch_pass.cpp",
        spirv_opt_path ++ "source/opt/loop_utils.cpp",
        spirv_opt_path ++ "source/opt/interp_fixup_pass.cpp",
        spirv_opt_path ++ "source/opt/mem_pass.cpp",
        spirv_opt_path ++ "source/opt/merge_return_pass.cpp",
        spirv_opt_path ++ "source/opt/module.cpp",
        spirv_opt_path ++ "source/opt/optimizer.cpp",
        spirv_opt_path ++ "source/opt/pass.cpp",
        spirv_opt_path ++ "source/opt/pass_manager.cpp",
        spirv_opt_path ++ "source/opt/pch_source_opt.cpp",
        spirv_opt_path ++ "source/opt/private_to_local_pass.cpp",
        spirv_opt_path ++ "source/opt/propagator.cpp",
        spirv_opt_path ++ "source/opt/reduce_load_size.cpp",
        spirv_opt_path ++ "source/opt/redundancy_elimination.cpp",
        spirv_opt_path ++ "source/opt/remove_dontinline_pass.cpp",
        spirv_opt_path ++ "source/opt/remove_unused_interface_variables_pass.cpp",
        spirv_opt_path ++ "source/opt/register_pressure.cpp",
        spirv_opt_path ++ "source/opt/relax_float_ops_pass.cpp",
        spirv_opt_path ++ "source/opt/remove_duplicates_pass.cpp",
        spirv_opt_path ++ "source/opt/replace_invalid_opc.cpp",
        spirv_opt_path ++ "source/opt/replace_desc_array_access_using_var_index.cpp",
        spirv_opt_path ++ "source/opt/scalar_analysis.cpp",
        spirv_opt_path ++ "source/opt/scalar_analysis_simplification.cpp",
        spirv_opt_path ++ "source/opt/scalar_replacement_pass.cpp",
        spirv_opt_path ++ "source/opt/set_spec_constant_default_value_pass.cpp",
        spirv_opt_path ++ "source/opt/simplification_pass.cpp",
        spirv_opt_path ++ "source/opt/spread_volatile_semantics.cpp",
        spirv_opt_path ++ "source/opt/ssa_rewrite_pass.cpp",
        spirv_opt_path ++ "source/opt/strength_reduction_pass.cpp",
        spirv_opt_path ++ "source/opt/strip_debug_info_pass.cpp",
        spirv_opt_path ++ "source/opt/strip_nonsemantic_info_pass.cpp",
        spirv_opt_path ++ "source/opt/struct_cfg_analysis.cpp",
        spirv_opt_path ++ "source/opt/type_manager.cpp",
        spirv_opt_path ++ "source/opt/types.cpp",
        spirv_opt_path ++ "source/opt/unify_const_pass.cpp",
        spirv_opt_path ++ "source/opt/upgrade_memory_model.cpp",
        spirv_opt_path ++ "source/opt/value_number_table.cpp",
        spirv_opt_path ++ "source/opt/vector_dce.cpp",
        spirv_opt_path ++ "source/opt/workaround1209.cpp",
        spirv_opt_path ++ "source/opt/wrap_opkill.cpp",
        spirv_opt_path ++ "source/parsed_operand.cpp",
        spirv_opt_path ++ "source/print.cpp",
        spirv_opt_path ++ "source/reduce/change_operand_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/change_operand_to_undef_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/conditional_branch_to_simple_conditional_branch_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/conditional_branch_to_simple_conditional_branch_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/merge_blocks_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/merge_blocks_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/operand_to_const_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/operand_to_dominating_id_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/operand_to_undef_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/pch_source_reduce.cpp",
        spirv_opt_path ++ "source/reduce/reducer.cpp",
        spirv_opt_path ++ "source/reduce/reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/reduction_pass.cpp",
        spirv_opt_path ++ "source/reduce/reduction_util.cpp",
        spirv_opt_path ++ "source/reduce/remove_block_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/remove_block_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/remove_function_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/remove_function_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/remove_instruction_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/remove_selection_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/remove_selection_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/remove_unused_instruction_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/simple_conditional_branch_to_branch_opportunity_finder.cpp",
        spirv_opt_path ++ "source/reduce/simple_conditional_branch_to_branch_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/structured_loop_to_selection_reduction_opportunity.cpp",
        spirv_opt_path ++ "source/reduce/structured_loop_to_selection_reduction_opportunity_finder.cpp",
        spirv_opt_path ++ "source/software_version.cpp",
        spirv_opt_path ++ "source/spirv_endian.cpp",
        spirv_opt_path ++ "source/spirv_optimizer_options.cpp",
        spirv_opt_path ++ "source/spirv_reducer_options.cpp",
        spirv_opt_path ++ "source/spirv_target_env.cpp",
        spirv_opt_path ++ "source/spirv_validator_options.cpp",
        spirv_opt_path ++ "source/table.cpp",
        spirv_opt_path ++ "source/text.cpp",
        spirv_opt_path ++ "source/text_handler.cpp",
        spirv_opt_path ++ "source/util/bit_vector.cpp",
        spirv_opt_path ++ "source/util/parse_number.cpp",
        spirv_opt_path ++ "source/util/string_utils.cpp",
        spirv_opt_path ++ "source/val/basic_block.cpp",
        spirv_opt_path ++ "source/val/construct.cpp",
        spirv_opt_path ++ "source/val/function.cpp",
        spirv_opt_path ++ "source/val/instruction.cpp",
        spirv_opt_path ++ "source/val/validate.cpp",
        spirv_opt_path ++ "source/val/validate_adjacency.cpp",
        spirv_opt_path ++ "source/val/validate_annotation.cpp",
        spirv_opt_path ++ "source/val/validate_arithmetics.cpp",
        spirv_opt_path ++ "source/val/validate_atomics.cpp",
        spirv_opt_path ++ "source/val/validate_barriers.cpp",
        spirv_opt_path ++ "source/val/validate_bitwise.cpp",
        spirv_opt_path ++ "source/val/validate_builtins.cpp",
        spirv_opt_path ++ "source/val/validate_capability.cpp",
        spirv_opt_path ++ "source/val/validate_cfg.cpp",
        spirv_opt_path ++ "source/val/validate_composites.cpp",
        spirv_opt_path ++ "source/val/validate_constants.cpp",
        spirv_opt_path ++ "source/val/validate_conversion.cpp",
        spirv_opt_path ++ "source/val/validate_debug.cpp",
        spirv_opt_path ++ "source/val/validate_decorations.cpp",
        spirv_opt_path ++ "source/val/validate_derivatives.cpp",
        spirv_opt_path ++ "source/val/validate_execution_limitations.cpp",
        spirv_opt_path ++ "source/val/validate_extensions.cpp",
        spirv_opt_path ++ "source/val/validate_function.cpp",
        spirv_opt_path ++ "source/val/validate_id.cpp",
        spirv_opt_path ++ "source/val/validate_image.cpp",
        spirv_opt_path ++ "source/val/validate_instruction.cpp",
        spirv_opt_path ++ "source/val/validate_interfaces.cpp",
        spirv_opt_path ++ "source/val/validate_layout.cpp",
        spirv_opt_path ++ "source/val/validate_literals.cpp",
        spirv_opt_path ++ "source/val/validate_logicals.cpp",
        spirv_opt_path ++ "source/val/validate_memory.cpp",
        spirv_opt_path ++ "source/val/validate_memory_semantics.cpp",
        spirv_opt_path ++ "source/val/validate_mesh_shading.cpp",
        spirv_opt_path ++ "source/val/validate_misc.cpp",
        spirv_opt_path ++ "source/val/validate_mode_setting.cpp",
        spirv_opt_path ++ "source/val/validate_non_uniform.cpp",
        spirv_opt_path ++ "source/val/validate_primitives.cpp",
        spirv_opt_path ++ "source/val/validate_ray_query.cpp",
        spirv_opt_path ++ "source/val/validate_ray_tracing.cpp",
        spirv_opt_path ++ "source/val/validate_ray_tracing_reorder.cpp",
        spirv_opt_path ++ "source/val/validate_scopes.cpp",
        spirv_opt_path ++ "source/val/validate_small_type_uses.cpp",
        spirv_opt_path ++ "source/val/validate_type.cpp",
        spirv_opt_path ++ "source/val/validation_state.cpp",
    }, &spirv_opt_cxx_options);

    spirv_opt_lib.want_lto = false;
    spirv_opt_lib.linkSystemLibrary("c++");

    const spirv_opt_lib_artifact = b.addInstallArtifact(spirv_opt_lib, .{});
    b.getInstallStep().dependOn(&spirv_opt_lib_artifact.step);

    // spriv-cross
    const spirv_cross_cxx_options = [_][]const u8{
        "-D__STDC_LIMIT_MACROS",
        "-D__STDC_FORMAT_MACROS",
        "-D__STDC_CONSTANT_MACROS",
        "-DSPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
        "-fno-sanitize=undefined",
    };

    const spirv_cross_path = "3rdparty/bgfx/3rdparty/spirv-cross/";
    const spirv_cross_lib = b.addStaticLibrary(.{ .name = "spirv-cross", .target = target, .optimize = build_mode});
    spirv_cross_lib.addIncludePath(.{ .path = spirv_cross_path ++ "include"});
    spirv_cross_lib.addCSourceFiles(&.{
        spirv_cross_path ++ "spirv_cfg.cpp",
        spirv_cross_path ++ "spirv_cpp.cpp",
        spirv_cross_path ++ "spirv_cross.cpp",
        spirv_cross_path ++ "spirv_cross_parsed_ir.cpp",
        spirv_cross_path ++ "spirv_cross_util.cpp",
        spirv_cross_path ++ "spirv_glsl.cpp",
        spirv_cross_path ++ "spirv_hlsl.cpp",
        spirv_cross_path ++ "spirv_msl.cpp",
        spirv_cross_path ++ "spirv_parser.cpp",
        spirv_cross_path ++ "spirv_reflect.cpp",
    }, &spirv_cross_cxx_options);

    spirv_cross_lib.want_lto = false;
    spirv_cross_lib.linkSystemLibrary("c++");

    const spirv_cross_lib_artifact = b.addInstallArtifact(spirv_cross_lib, .{});
    b.getInstallStep().dependOn(&spirv_cross_lib_artifact.step);

    // glslang
    const glslang_cxx_options = [_][]const u8{
        "-D__STDC_LIMIT_MACROS",
        "-D__STDC_FORMAT_MACROS",
        "-D__STDC_CONSTANT_MACROS",
        "-DENABLE_OPT=1",
        "-DENABLE_HLSL=1",
        "-fno-sanitize=undefined",
    };

    const glslang_path = "3rdparty/bgfx/3rdparty/glslang/";
    const glslang_lib = b.addStaticLibrary(.{ .name = "glslang", .target = target, .optimize = build_mode});
    glslang_lib.addIncludePath(.{ .path = "3rdparty/bgfx/3rdparty"});
    glslang_lib.addIncludePath(.{ .path = glslang_path});
    glslang_lib.addIncludePath(.{ .path = glslang_path ++ "include"});
    glslang_lib.addSystemIncludePath(.{ .path = spirv_opt_path ++ "include"});
    glslang_lib.addSystemIncludePath(.{ .path = spirv_opt_path ++ "source"});
    glslang_lib.addCSourceFiles(&.{
        glslang_path ++ "OGLCompilersDLL/InitializeDll.cpp",
        glslang_path ++ "SPIRV/GlslangToSpv.cpp",
        glslang_path ++ "SPIRV/InReadableOrder.cpp",
        glslang_path ++ "SPIRV/Logger.cpp",
        glslang_path ++ "SPIRV/SPVRemapper.cpp",
        glslang_path ++ "SPIRV/SpvBuilder.cpp",
        glslang_path ++ "SPIRV/SpvPostProcess.cpp",
        glslang_path ++ "SPIRV/SpvTools.cpp",
        glslang_path ++ "SPIRV/disassemble.cpp",
        glslang_path ++ "SPIRV/doc.cpp",
        glslang_path ++ "glslang/GenericCodeGen/CodeGen.cpp",
        glslang_path ++ "glslang/GenericCodeGen/Link.cpp",
        glslang_path ++ "glslang/HLSL/hlslAttributes.cpp",
        glslang_path ++ "glslang/HLSL/hlslGrammar.cpp",
        glslang_path ++ "glslang/HLSL/hlslOpMap.cpp",
        glslang_path ++ "glslang/HLSL/hlslParseHelper.cpp",
        glslang_path ++ "glslang/HLSL/hlslParseables.cpp",
        glslang_path ++ "glslang/HLSL/hlslScanContext.cpp",
        glslang_path ++ "glslang/HLSL/hlslTokenStream.cpp",
        glslang_path ++ "glslang/MachineIndependent/Constant.cpp",
        glslang_path ++ "glslang/MachineIndependent/InfoSink.cpp",
        glslang_path ++ "glslang/MachineIndependent/Initialize.cpp",
        glslang_path ++ "glslang/MachineIndependent/IntermTraverse.cpp",
        glslang_path ++ "glslang/MachineIndependent/Intermediate.cpp",
        glslang_path ++ "glslang/MachineIndependent/ParseContextBase.cpp",
        glslang_path ++ "glslang/MachineIndependent/ParseHelper.cpp",
        glslang_path ++ "glslang/MachineIndependent/PoolAlloc.cpp",
        glslang_path ++ "glslang/MachineIndependent/RemoveTree.cpp",
        glslang_path ++ "glslang/MachineIndependent/Scan.cpp",
        glslang_path ++ "glslang/MachineIndependent/ShaderLang.cpp",
        glslang_path ++ "glslang/MachineIndependent/SymbolTable.cpp",
        glslang_path ++ "glslang/MachineIndependent/SpirvIntrinsics.cpp",
        glslang_path ++ "glslang/MachineIndependent/Versions.cpp",
        glslang_path ++ "glslang/MachineIndependent/attribute.cpp",
        glslang_path ++ "glslang/MachineIndependent/glslang_tab.cpp",
        glslang_path ++ "glslang/MachineIndependent/intermOut.cpp",
        glslang_path ++ "glslang/MachineIndependent/iomapper.cpp",
        glslang_path ++ "glslang/MachineIndependent/limits.cpp",
        glslang_path ++ "glslang/MachineIndependent/linkValidate.cpp",
        glslang_path ++ "glslang/MachineIndependent/parseConst.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/Pp.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpAtom.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpContext.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpScanner.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpTokens.cpp",
        glslang_path ++ "glslang/MachineIndependent/propagateNoContraction.cpp",
        glslang_path ++ "glslang/MachineIndependent/reflection.cpp",
    }, &glslang_cxx_options);

    if (target.isWindows()) {
        glslang_lib.addCSourceFile(.{ .file = .{ .path = glslang_path ++ "glslang/OSDependent/Windows/ossource.cpp"}, .flags = &glslang_cxx_options});
    }
    if (target.isLinux() or target.isDarwin()) {
        glslang_lib.addCSourceFile(.{ .file = .{ .path = glslang_path ++ "glslang/OSDependent/Unix/ossource.cpp"}, .flags = &glslang_cxx_options});
    }

    glslang_lib.want_lto = false;
    glslang_lib.linkSystemLibrary("c++");

    const glslang_lib_artifact = b.addInstallArtifact(glslang_lib, .{});
    b.getInstallStep().dependOn(&glslang_lib_artifact.step);

    // glslang
    const glsl_optimizer_cxx_options = [_][]const u8{
        "-MMD",
        "-MP",
        "-MP",
        "-Wall",
        "-Wextra",
        "-ffast-math",
        "-fomit-frame-pointer",
        "-g",
        "-m64",
        "-std=c++14",
        "-fno-rtti",
        "-fno-exceptions",
        "-D__STDC_LIMIT_MACROS",
        "-D__STDC_FORMAT_MACROS",
        "-D__STDC_CONSTANT_MACROS",
        "-fno-sanitize=undefined",
    };

    const glsl_optimizer_c_options = [_][]const u8{
        "-MMD",
        "-MP",
        "-MP",
        "-Wall",
        "-Wextra",
        "-ffast-math",
        "-fomit-frame-pointer",
        "-g",
        "-m64",
        "-D__STDC_LIMIT_MACROS",
        "-D__STDC_FORMAT_MACROS",
        "-D__STDC_CONSTANT_MACROS",
        "-fno-sanitize=undefined",
    };

    const glsl_optimizer_path = "3rdparty/bgfx/3rdparty/glsl-optimizer/";
    const glsl_optimizer_lib = b.addStaticLibrary(.{ .name = "glsl-optimizer", .target = target, .optimize = build_mode});
    glsl_optimizer_lib.addIncludePath(.{ .path = glsl_optimizer_path ++ "include"});
    glsl_optimizer_lib.addIncludePath(.{ .path = glsl_optimizer_path ++ "src"});
    glsl_optimizer_lib.addIncludePath(.{ .path = glsl_optimizer_path ++ "src/mesa"});
    glsl_optimizer_lib.addIncludePath(.{ .path = glsl_optimizer_path ++ "src/mapi"});
    glsl_optimizer_lib.addIncludePath(.{ .path = glsl_optimizer_path ++ "src/glsl"});

    // add C++ files
    glsl_optimizer_lib.addCSourceFiles(&.{
        glsl_optimizer_path ++ "src/glsl/ast_array_index.cpp",
        glsl_optimizer_path ++ "src/glsl/ast_expr.cpp",
        glsl_optimizer_path ++ "src/glsl/ast_function.cpp",
        glsl_optimizer_path ++ "src/glsl/ast_to_hir.cpp",
        glsl_optimizer_path ++ "src/glsl/ast_type.cpp",
        glsl_optimizer_path ++ "src/glsl/builtin_functions.cpp",
        glsl_optimizer_path ++ "src/glsl/builtin_types.cpp",
        glsl_optimizer_path ++ "src/glsl/builtin_variables.cpp",
        glsl_optimizer_path ++ "src/glsl/glsl_lexer.cpp",
        glsl_optimizer_path ++ "src/glsl/glsl_optimizer.cpp",
        glsl_optimizer_path ++ "src/glsl/glsl_parser.cpp",
        glsl_optimizer_path ++ "src/glsl/glsl_parser_extras.cpp",
        glsl_optimizer_path ++ "src/glsl/glsl_symbol_table.cpp",
        glsl_optimizer_path ++ "src/glsl/glsl_types.cpp",
        glsl_optimizer_path ++ "src/glsl/hir_field_selection.cpp",
        glsl_optimizer_path ++ "src/glsl/ir.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_basic_block.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_builder.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_clone.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_constant_expression.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_equals.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_expression_flattening.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_function.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_function_can_inline.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_function_detect_recursion.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_hierarchical_visitor.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_hv_accept.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_import_prototypes.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_print_glsl_visitor.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_print_metal_visitor.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_print_visitor.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_rvalue_visitor.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_stats.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_unused_structs.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_validate.cpp",
        glsl_optimizer_path ++ "src/glsl/ir_variable_refcount.cpp",
        glsl_optimizer_path ++ "src/glsl/link_atomics.cpp",
        glsl_optimizer_path ++ "src/glsl/link_functions.cpp",
        glsl_optimizer_path ++ "src/glsl/link_interface_blocks.cpp",
        glsl_optimizer_path ++ "src/glsl/link_uniform_block_active_visitor.cpp",
        glsl_optimizer_path ++ "src/glsl/link_uniform_blocks.cpp",
        glsl_optimizer_path ++ "src/glsl/link_uniform_initializers.cpp",
        glsl_optimizer_path ++ "src/glsl/link_uniforms.cpp",
        glsl_optimizer_path ++ "src/glsl/link_varyings.cpp",
        glsl_optimizer_path ++ "src/glsl/linker.cpp",
        glsl_optimizer_path ++ "src/glsl/loop_analysis.cpp",
        glsl_optimizer_path ++ "src/glsl/loop_controls.cpp",
        glsl_optimizer_path ++ "src/glsl/loop_unroll.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_clip_distance.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_discard.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_discard_flow.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_if_to_cond_assign.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_instructions.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_jumps.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_mat_op_to_vec.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_named_interface_blocks.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_noise.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_offset_array.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_output_reads.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_packed_varyings.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_packing_builtins.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_ubo_reference.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_variable_index_to_cond_assign.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_vec_index_to_cond_assign.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_vec_index_to_swizzle.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_vector.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_vector_insert.cpp",
        glsl_optimizer_path ++ "src/glsl/lower_vertex_id.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_algebraic.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_array_splitting.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_constant_folding.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_constant_propagation.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_constant_variable.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_copy_propagation.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_copy_propagation_elements.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_cse.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_dead_builtin_variables.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_dead_builtin_varyings.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_dead_code.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_dead_code_local.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_dead_functions.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_flatten_nested_if_blocks.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_flip_matrices.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_function_inlining.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_if_simplification.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_minmax.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_noop_swizzle.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_rebalance_tree.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_redundant_jumps.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_structure_splitting.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_swizzle_swizzle.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_tree_grafting.cpp",
        glsl_optimizer_path ++ "src/glsl/opt_vectorize.cpp",
        glsl_optimizer_path ++ "src/glsl/s_expression.cpp",
        glsl_optimizer_path ++ "src/glsl/standalone_scaffolding.cpp",
    }, &glsl_optimizer_cxx_options);

    // adding C files
    glsl_optimizer_lib.addCSourceFiles(&.{
        glsl_optimizer_path ++ "src/glsl/glcpp/glcpp-lex.c",
        glsl_optimizer_path ++ "src/glsl/glcpp/glcpp-parse.c",
        glsl_optimizer_path ++ "src/glsl/glcpp/pp.c",
        glsl_optimizer_path ++ "src/glsl/strtod.c",
        glsl_optimizer_path ++ "src/mesa/main/imports.c",
        glsl_optimizer_path ++ "src/mesa/program/prog_hash_table.c",
        glsl_optimizer_path ++ "src/mesa/program/symbol_table.c",
        glsl_optimizer_path ++ "src/util/hash_table.c",
        glsl_optimizer_path ++ "src/util/ralloc.c",
    }, &glsl_optimizer_c_options);

    glsl_optimizer_lib.want_lto = false;
    glsl_optimizer_lib.linkSystemLibrary("c++");

    const glsl_optimizer_lib_artifact = b.addInstallArtifact(glsl_optimizer_lib, .{});
    b.getInstallStep().dependOn(&glsl_optimizer_lib_artifact.step);

    const shaderc_cxx_options = [_][]const u8{
        "-D__STDC_LIMIT_MACROS",
        "-D__STDC_FORMAT_MACROS",
        "-D__STDC_CONSTANT_MACROS",
        "-DBX_CONFIG_DEBUG",
        "-DSHADERC_STANDALONE",
        "-fno-sanitize=undefined",
    };
    const bgfx_path = "3rdparty/bgfx/";
    const bx_path = "3rdparty/bx/";

    const exe = b.addExecutable(.{
        .name = "shaderc",
        .target = target,
        .optimize = build_mode,
    });

    exe.addIncludePath(.{ .path = bx_path ++ "3rdparty"});
    exe.addIncludePath(.{ .path = bx_path ++ "include"});
    exe.addIncludePath(.{ .path = bx_path ++ "/include/compat/osx"});
    exe.addIncludePath(.{ .path = "3rdparty/bimg/include"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "include"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "src"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/dxsdk/include"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/fcpp"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/glslang/glslang/Public"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/glslang/glslang/Include"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/glslang"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/glsl-optimizer/include"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/glsl-optimizer/src/glsl"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/spirv-cross"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/spirv-tools/include"});
    exe.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/webgpu/include"});
    exe.addCSourceFiles(&.{
        bx_path ++ "src/amalgamated.cpp",
    }, &shaderc_cxx_options);
    exe.addCSourceFiles(&.{
        bgfx_path ++ "src/shader.cpp",
        bgfx_path ++ "src/shader_dx9bc.cpp",
        bgfx_path ++ "src/shader_dxbc.cpp",
        bgfx_path ++ "src/shader_spirv.cpp",
        bgfx_path ++ "src/vertexlayout.cpp",
        bgfx_path ++ "tools/shaderc/shaderc.cpp",
        bgfx_path ++ "tools/shaderc/shaderc_glsl.cpp",
        bgfx_path ++ "tools/shaderc/shaderc_hlsl.cpp",
        bgfx_path ++ "tools/shaderc/shaderc_metal.cpp",
        bgfx_path ++ "tools/shaderc/shaderc_pssl.cpp",
        bgfx_path ++ "tools/shaderc/shaderc_spirv.cpp",
    }, &shaderc_cxx_options);

    exe.want_lto = false;

    exe.linkLibrary(fcpp_lib);
    exe.linkLibrary(glslang_lib);
    exe.linkLibrary(glsl_optimizer_lib);
    exe.linkLibrary(spirv_opt_lib);
    exe.linkLibrary(spirv_cross_lib);
    exe.linkSystemLibrary("c++");

    if (target.isDarwin()) {
        exe.linkFramework("CoreFoundation");
        exe.linkFramework("Foundation");
    }

    const install_exe = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);
    return exe;
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
