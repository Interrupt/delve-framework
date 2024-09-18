const std = @import("std");

const Build = std.Build;
const Step = std.Build.Step;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = target.result;

    const lib = b.addStaticLibrary(.{
        .name = "SDL3",
        .target = target,
        .optimize = optimize,
    });

    const upstream = b.dependency("sdl_src", .{
        .target = target,
        .optimize = optimize,
    });

    const upstream_root = .{ .dependency = .{
        .dependency = upstream,
        .sub_path = "",
    } };

    lib.addIncludePath(upstream.path("include"));
    lib.addIncludePath(upstream.path("src"));
    lib.addIncludePath(upstream.path("src/hidapi/hidapi"));

    lib.addCSourceFiles(.{
        .root = upstream_root,
        .files = &generic_src_files,
    });
    lib.defineCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", "1");
    lib.linkLibC();

    switch (t.os.tag) {
        .linux => {
            lib.addIncludePath(upstream.path("src/hidapi/linux"));
            lib.addCSourceFiles(.{ .root = upstream_root, .files = &linux_src_files });
        },
        .windows => {
            lib.addIncludePath(upstream.path("src/hidapi/windows"));
            lib.addCSourceFiles(.{ .root = upstream_root, .files = &windows_src_files });
            lib.linkSystemLibrary("setupapi");
            lib.linkSystemLibrary("winmm");
            lib.linkSystemLibrary("gdi32");
            lib.linkSystemLibrary("imm32");
            lib.linkSystemLibrary("version");
            lib.linkSystemLibrary("oleaut32");
            lib.linkSystemLibrary("ole32");
        },
        .macos => {
            lib.addCSourceFiles(.{ .root = upstream_root, .files = &darwin_src_files });
            lib.addCSourceFiles(.{
                .root = upstream_root,
                .files = &objective_c_src_files,
                .flags = &.{"-fobjc-arc"},
            });
            lib.linkFramework("OpenGL");
            lib.linkFramework("Metal");
            lib.linkFramework("CoreVideo");
            lib.linkFramework("Cocoa");
            lib.linkFramework("IOKit");
            lib.linkFramework("ForceFeedback");
            lib.linkFramework("Carbon");
            lib.linkFramework("CoreAudio");
            lib.linkFramework("AudioToolbox");
            lib.linkFramework("AVFoundation");
            lib.linkFramework("Foundation");
        },
        .emscripten => {
            // NOTE: Currently this include path is injected by the delve build.
            //       Previously we looked for the 'sysroot' property to be defined on our builder.
            //       But at the moment, there is a chicken and egg problem in that we get the emsdk
            //       from the sokol module rather than using it ourselves.
            lib.defineCMacro("__EMSCRIPTEN_PTHREADS__ ", "1");
            lib.addCSourceFiles(.{ .root = upstream_root, .files = &emscripten_src_files });
        },
        else => {},
    }

    const use_pregenerated_config = switch (t.os.tag) {
        .windows, .macos, .emscripten => true,
        else => false,
    };

    if (use_pregenerated_config) {
        lib.addIncludePath(upstream.path("include/build_config"));
        lib.installHeadersDirectory(upstream.path("include/build_config"), "SDL3", .{});
        applyOptions(&global_options, b, lib, upstream_root);
    } else {
        // causes pregenerated SDL_config.h to assert an error
        lib.defineCMacro("USING_GENERATED_CONFIG_H", "");

        const config_header = b.addConfigHeader(.{
            .style = .{ .cmake = upstream.path("include/build_config/SDL_build_config.h.cmake") },
            .include_path = "SDL_build_config.h",
        }, .{
            .HAVE_STDINT_H = 1,
            .HAVE_SYS_TYPES_H = 1,
            .HAVE_STDIO_H = 1,
            .HAVE_STRING_H = 1,
            .HAVE_ALLOCA_H = 1,
            .HAVE_CTYPE_H = 1,
            .HAVE_FLOAT_H = 1,
            .HAVE_ICONV_H = 1,
            .HAVE_INTTYPES_H = 1,
            .HAVE_LIMITS_H = 1,
            .HAVE_MALLOC_H = 1,
            .HAVE_MATH_H = 1,
            .HAVE_MEMORY_H = 1,
            .HAVE_SIGNAL_H = 1,
            .HAVE_STDARG_H = 1,
            .HAVE_STDDEF_H = 1,
            .HAVE_STDLIB_H = 1,
            .HAVE_STRINGS_H = 1,
            .HAVE_WCHAR_H = 1,
            .HAVE_LIBUNWIND_H = 1,
            .HAVE_LIBC = 1,
            .STDC_HEADERS = 1,
            .SDL_DEFAULT_ASSERT_LEVEL_CONFIGURED = 0,
            .SDL_AUDIO_DISABLED = 1,
            .SDL_AUDIO_DRIVER_DUMMY = 1,
            .SDL_CAMERA_DISABLED = 1,
            .SDL_CAMERA_DRIVER_DUMMY = 1,
            .SDL_SENSOR_DUMMY = 1,
        });
        switch (t.os.tag) {
            .linux => {
                config_header.addValues(.{
                    .SDL_LOADSO_DLOPEN = 1,
                    .HAVE_DLOPEN = 1,
                    .HAVE_MALLOC = 1,
                    .HAVE_CALLOC = 1,
                    .HAVE_REALLOC = 1,
                    .HAVE_FREE = 1,
                    .HAVE_GETENV = 1,
                    .HAVE_SETENV = 1,
                    .HAVE_PUTENV = 1,
                    .HAVE_UNSETENV = 1,
                    .HAVE_ABS = 1,
                    .HAVE_BCOPY = 1,
                    .HAVE_MEMSET = 1,
                    .HAVE_MEMCPY = 1,
                    .HAVE_MEMMOVE = 1,
                    .HAVE_MEMCMP = 1,
                    .HAVE_WCSLEN = 1,
                    .HAVE_WCSNLEN = 1,
                    // Not on Ubuntu Jammy
                    // .HAVE_WCSLCPY = 1,
                    // .HAVE_WCSLCAT = 1,
                    .HAVE_WCSDUP = 1,
                    .HAVE_WCSSTR = 1,
                    .HAVE_WCSCMP = 1,
                    .HAVE_WCSNCMP = 1,
                    .HAVE_WCSTOL = 1,
                    .HAVE_STRLEN = 1,
                    .HAVE_STRNLEN = 1,
                    // Not on Ubuntu Jammy
                    // .HAVE_STRLCPY = 1,
                    // .HAVE_STRLCAT = 1,
                    .HAVE_STRPBRK = 1,
                    .HAVE_INDEX = 1,
                    .HAVE_RINDEX = 1,
                    .HAVE_STRCHR = 1,
                    .HAVE_STRRCHR = 1,
                    .HAVE_STRSTR = 1,
                    .HAVE_STRTOK_R = 1,
                    .HAVE_STRTOL = 1,
                    .HAVE_STRTOUL = 1,
                    .HAVE_STRTOLL = 1,
                    .HAVE_STRTOULL = 1,
                    .HAVE_STRTOD = 1,
                    .HAVE_ATOI = 1,
                    .HAVE_ATOF = 1,
                    .HAVE_STRCMP = 1,
                    .HAVE_STRNCMP = 1,
                    .HAVE_STRCASESTR = 1,
                    .HAVE_SSCANF = 1,
                    .HAVE_VSSCANF = 1,
                    .HAVE_VSNPRINTF = 1,
                    .HAVE_ACOS = 1,
                    .HAVE_ACOSF = 1,
                    .HAVE_ASIN = 1,
                    .HAVE_ASINF = 1,
                    .HAVE_ATAN = 1,
                    .HAVE_ATANF = 1,
                    .HAVE_ATAN2 = 1,
                    .HAVE_ATAN2F = 1,
                    .HAVE_CEIL = 1,
                    .HAVE_CEILF = 1,
                    .HAVE_COPYSIGN = 1,
                    .HAVE_COPYSIGNF = 1,
                    .HAVE_COS = 1,
                    .HAVE_COSF = 1,
                    .HAVE_EXP = 1,
                    .HAVE_EXPF = 1,
                    .HAVE_FABS = 1,
                    .HAVE_FABSF = 1,
                    .HAVE_FLOOR = 1,
                    .HAVE_FLOORF = 1,
                    .HAVE_FMOD = 1,
                    .HAVE_FMODF = 1,
                    .HAVE_ISINF = 1,
                    .HAVE_ISINFF = 1,
                    .HAVE_ISINF_FLOAT_MACRO = 1,
                    .HAVE_ISNAN = 1,
                    .HAVE_ISNANF = 1,
                    .HAVE_ISNAN_FLOAT_MACRO = 1,
                    .HAVE_LOG = 1,
                    .HAVE_LOGF = 1,
                    .HAVE_LOG10 = 1,
                    .HAVE_LOG10F = 1,
                    .HAVE_LROUND = 1,
                    .HAVE_LROUNDF = 1,
                    .HAVE_MODF = 1,
                    .HAVE_MODFF = 1,
                    .HAVE_POW = 1,
                    .HAVE_POWF = 1,
                    .HAVE_ROUND = 1,
                    .HAVE_ROUNDF = 1,
                    .HAVE_SCALBN = 1,
                    .HAVE_SCALBNF = 1,
                    .HAVE_SIN = 1,
                    .HAVE_SINF = 1,
                    .HAVE_SQRT = 1,
                    .HAVE_SQRTF = 1,
                    .HAVE_TAN = 1,
                    .HAVE_TANF = 1,
                    .HAVE_TRUNC = 1,
                    .HAVE_TRUNCF = 1,
                    .HAVE_FOPEN64 = 1,
                    .HAVE_FSEEKO = 1,
                    .HAVE_FSEEKO64 = 1,
                    .HAVE_MEMFD_CREATE = 1,
                    .HAVE_POSIX_FALLOCATE = 1,
                    .HAVE_SIGACTION = 1,
                    .HAVE_SA_SIGACTION = 1,
                    .HAVE_ST_MTIM = 1,
                    .HAVE_SETJMP = 1,
                    .HAVE_NANOSLEEP = 1,
                    .HAVE_GMTIME_R = 1,
                    .HAVE_LOCALTIME_R = 1,
                    .HAVE_NL_LANGINFO = 1,
                    .HAVE_SYSCONF = 1,
                    .HAVE_CLOCK_GETTIME = 1,
                    .HAVE_GETPAGESIZE = 1,
                    .HAVE_ICONV = 1,
                    .HAVE_PTHREAD_SETNAME_NP = 1,
                    .HAVE_SEM_TIMEDWAIT = 1,
                    .HAVE_GETAUXVAL = 1,
                    .HAVE_POLL = 1,
                    .HAVE__EXIT = 1,
                    .HAVE_SYS_INOTIFY_H = 1,
                    .HAVE_INOTIFY_INIT = 1,
                    .HAVE_INOTIFY_INIT1 = 1,
                    .HAVE_INOTIFY = 1,
                    .HAVE_O_CLOEXEC = 1,
                    .HAVE_LINUX_INPUT_H = 1,
                    .SDL_INPUT_LINUXEV = 1,
                    .SDL_INPUT_LINUXKD = 1,
                    .SDL_JOYSTICK_HIDAPI = 1,
                    .SDL_JOYSTICK_LINUX = 1,
                    .SDL_JOYSTICK_VIRTUAL = 1,
                    .SDL_HAPTIC_LINUX = 1,
                    .SDL_PROCESS_POSIX = 1,
                    .SDL_THREAD_PTHREAD = 1,
                    .SDL_THREAD_PTHREAD_RECURSIVE_MUTEX = 1,
                    .SDL_TIME_UNIX = 1,
                    .SDL_TIMER_UNIX = 1,
                    .SDL_VIDEO_DRIVER_DUMMY = 1,
                    .SDL_VIDEO_DRIVER_OFFSCREEN = 1,
                    .SDL_VIDEO_DRIVER_X11 = 1,
                    .SDL_VIDEO_DRIVER_X11_DYNAMIC = "\"libX11.so.6\"",
                    .SDL_VIDEO_DRIVER_X11_DYNAMIC_XCURSOR = "\"libXcursor.so.1\"",
                    .SDL_VIDEO_DRIVER_X11_DYNAMIC_XEXT = "\"libXext.so.6\"",
                    .SDL_VIDEO_DRIVER_X11_DYNAMIC_XFIXES = "\"libXfixes.so.3\"",
                    .SDL_VIDEO_DRIVER_X11_DYNAMIC_XINPUT2 = "\"libXi.so.6\"",
                    .SDL_VIDEO_DRIVER_X11_DYNAMIC_XRANDR = "\"libXrandr.so.2\"",
                    .SDL_VIDEO_DRIVER_X11_DYNAMIC_XSS = "\"libXss.so.1\"",
                    .SDL_VIDEO_DRIVER_X11_HAS_XKBLOOKUPKEYSYM = 1,
                    .SDL_VIDEO_DRIVER_X11_SUPPORTS_GENERIC_EVENTS = 1,
                    .SDL_VIDEO_DRIVER_X11_XCURSOR = 1,
                    .SDL_VIDEO_DRIVER_X11_XDBE = 1,
                    .SDL_VIDEO_DRIVER_X11_XFIXES = 1,
                    .SDL_VIDEO_DRIVER_X11_XINPUT2 = 1,
                    .SDL_VIDEO_DRIVER_X11_XINPUT2_SUPPORTS_MULTITOUCH = 1,
                    .SDL_VIDEO_DRIVER_X11_XRANDR = 1,
                    .SDL_VIDEO_DRIVER_X11_XSCRNSAVER = 1,
                    .SDL_VIDEO_DRIVER_X11_XSHAPE = 1,
                    .SDL_VIDEO_OPENGL = 1,
                    .SDL_VIDEO_OPENGL_GLX = 1,
                    .SDL_VIDEO_VULKAN = 1,
                    .SDL_GPU_VULKAN = 1,
                    .SDL_POWER_LINUX = 1,
                    .SDL_FILESYSTEM_UNIX = 1,
                    .SDL_STORAGE_GENERIC = 1,
                    .SDL_STORAGE_STEAM = 1,
                    .SDL_FSOPS_POSIX = 1,
                    //.SDL_CAMERA_DRIVER_V4L2 = 1,
                    .DYNAPI_NEEDS_DLOPEN = 1,
                    .SDL_DISABLE_LSX = 1,
                    .SDL_DISABLE_LASX = 1,
                    .SDL_DISABLE_NEON = 1,
                });
                applyOptionsWithConfig(&linux_options, b, lib, upstream_root, config_header);
                applyOptionsWithConfig(&global_options, b, lib, upstream_root, config_header);
            },
            else => {},
        }
        lib.addConfigHeader(config_header);
        lib.installConfigHeader(config_header);

        const revision_header = b.addConfigHeader(.{
            .style = .{ .cmake = upstream.path("include/build_config/SDL_revision.h.cmake") },
            .include_path = "SDL_revision.h",
        }, .{});
        lib.addConfigHeader(revision_header);
        lib.installConfigHeader(revision_header);
    }
    lib.installHeadersDirectory(upstream.path("include/SDL3"), "SDL3", .{});
    b.installArtifact(lib);
}

const generic_src_files = [_][]const u8{
    "src/SDL.c",
    "src/SDL_assert.c",
    "src/SDL_error.c",
    "src/SDL_guid.c",
    "src/SDL_hashtable.c",
    "src/SDL_hints.c",
    "src/SDL_list.c",
    "src/SDL_log.c",
    "src/SDL_properties.c",
    "src/SDL_utils.c",

    "src/atomic/SDL_atomic.c",
    "src/atomic/SDL_spinlock.c",

    "src/audio/SDL_audio.c",
    "src/audio/SDL_audiocvt.c",
    "src/audio/SDL_audiodev.c",
    "src/audio/SDL_audioqueue.c",
    "src/audio/SDL_audioresample.c",
    "src/audio/SDL_audiotypecvt.c",
    "src/audio/SDL_mixer.c",
    "src/audio/SDL_wave.c",
    "src/audio/disk/SDL_diskaudio.c",
    "src/audio/dsp/SDL_dspaudio.c",
    "src/audio/dummy/SDL_dummyaudio.c",

    "src/camera/SDL_camera.c",
    "src/camera/dummy/SDL_camera_dummy.c",

    "src/core/SDL_core_unsupported.c",

    "src/cpuinfo/SDL_cpuinfo.c",

    "src/dialog/SDL_dialog_utils.c",

    "src/dynapi/SDL_dynapi.c",

    "src/events/SDL_categories.c",
    "src/events/SDL_clipboardevents.c",
    "src/events/SDL_displayevents.c",
    "src/events/SDL_dropevents.c",
    "src/events/SDL_events.c",
    "src/events/SDL_keyboard.c",
    "src/events/SDL_keymap.c",
    "src/events/SDL_keysym_to_scancode.c",
    "src/events/SDL_mouse.c",
    "src/events/SDL_pen.c",
    "src/events/SDL_quit.c",
    "src/events/SDL_scancode_tables.c",
    "src/events/SDL_touch.c",
    "src/events/SDL_windowevents.c",
    "src/events/imKStoUCS.c",

    "src/file/SDL_iostream.c",

    "src/filesystem/SDL_filesystem.c",

    "src/gpu/SDL_gpu.c",
    "src/gpu/vulkan/SDL_gpu_vulkan.c",

    "src/haptic/SDL_haptic.c",

    "src/hidapi/SDL_hidapi.c",

    "src/joystick/SDL_gamepad.c",
    "src/joystick/SDL_joystick.c",
    "src/joystick/SDL_steam_virtual_gamepad.c",
    "src/joystick/controller_type.c",
    "src/joystick/steam/SDL_steamcontroller.c",
    "src/joystick/virtual/SDL_virtualjoystick.c",

    "src/joystick/hidapi/SDL_hidapi_combined.c",
    "src/joystick/hidapi/SDL_hidapi_gamecube.c",
    "src/joystick/hidapi/SDL_hidapi_luna.c",
    "src/joystick/hidapi/SDL_hidapi_ps3.c",
    "src/joystick/hidapi/SDL_hidapi_ps4.c",
    "src/joystick/hidapi/SDL_hidapi_ps5.c",
    "src/joystick/hidapi/SDL_hidapi_rumble.c",
    "src/joystick/hidapi/SDL_hidapi_shield.c",
    "src/joystick/hidapi/SDL_hidapi_stadia.c",
    "src/joystick/hidapi/SDL_hidapi_steam.c",
    "src/joystick/hidapi/SDL_hidapi_steamdeck.c",
    "src/joystick/hidapi/SDL_hidapi_steam_hori.c",
    "src/joystick/hidapi/SDL_hidapi_switch.c",
    "src/joystick/hidapi/SDL_hidapi_wii.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360w.c",
    "src/joystick/hidapi/SDL_hidapi_xboxone.c",
    "src/joystick/hidapi/SDL_hidapijoystick.c",

    "src/libm/e_atan2.c",
    "src/libm/e_exp.c",
    "src/libm/e_fmod.c",
    "src/libm/e_log.c",
    "src/libm/e_log10.c",
    "src/libm/e_pow.c",
    "src/libm/e_rem_pio2.c",
    "src/libm/e_sqrt.c",
    "src/libm/k_cos.c",
    "src/libm/k_rem_pio2.c",
    "src/libm/k_sin.c",
    "src/libm/k_tan.c",
    "src/libm/s_atan.c",
    "src/libm/s_copysign.c",
    "src/libm/s_cos.c",
    "src/libm/s_fabs.c",
    "src/libm/s_floor.c",
    "src/libm/s_isinf.c",
    "src/libm/s_isinff.c",
    "src/libm/s_isnan.c",
    "src/libm/s_isnanf.c",
    "src/libm/s_modf.c",
    "src/libm/s_scalbn.c",
    "src/libm/s_sin.c",
    "src/libm/s_tan.c",

    "src/locale/SDL_locale.c",

    "src/main/SDL_main_callbacks.c",
    "src/main/SDL_runapp.c",
    "src/main/generic/SDL_sysmain_callbacks.c",

    "src/misc/SDL_url.c",

    "src/power/SDL_power.c",

    "src/process/SDL_process.c",

    "src/render/SDL_d3dmath.c",
    "src/render/SDL_render.c",
    "src/render/SDL_yuv_sw.c",

    "src/sensor/SDL_sensor.c",
    "src/sensor/dummy/SDL_dummysensor.c",

    "src/stdlib/SDL_crc16.c",
    "src/stdlib/SDL_crc32.c",
    "src/stdlib/SDL_getenv.c",
    "src/stdlib/SDL_iconv.c",
    "src/stdlib/SDL_malloc.c",
    "src/stdlib/SDL_memcpy.c",
    "src/stdlib/SDL_memmove.c",
    "src/stdlib/SDL_memset.c",
    "src/stdlib/SDL_mslibc.c",
    "src/stdlib/SDL_murmur3.c",
    "src/stdlib/SDL_qsort.c",
    "src/stdlib/SDL_random.c",
    "src/stdlib/SDL_stdlib.c",
    "src/stdlib/SDL_string.c",
    "src/stdlib/SDL_strtokr.c",

    "src/storage/SDL_storage.c",
    "src/storage/generic/SDL_genericstorage.c",
    "src/storage/steam/SDL_steamstorage.c",

    "src/thread/SDL_thread.c",

    // "src/thread/generic/SDL_sysmutex.c",

    "src/time/SDL_time.c",

    "src/timer/SDL_timer.c",

    "src/video/SDL_RLEaccel.c",
    "src/video/SDL_blit.c",
    "src/video/SDL_blit_0.c",
    "src/video/SDL_blit_1.c",
    "src/video/SDL_blit_A.c",
    "src/video/SDL_blit_N.c",
    "src/video/SDL_blit_auto.c",
    "src/video/SDL_blit_copy.c",
    "src/video/SDL_blit_slow.c",
    "src/video/SDL_bmp.c",
    "src/video/SDL_clipboard.c",
    "src/video/SDL_egl.c",
    "src/video/SDL_fillrect.c",
    "src/video/SDL_pixels.c",
    "src/video/SDL_rect.c",
    "src/video/SDL_stretch.c",
    "src/video/SDL_surface.c",
    "src/video/SDL_video.c",
    "src/video/SDL_video_unsupported.c",
    "src/video/SDL_vulkan_utils.c",
    "src/video/SDL_yuv.c",
    "src/video/yuv2rgb/yuv_rgb_lsx.c",
    "src/video/yuv2rgb/yuv_rgb_sse.c",
    "src/video/yuv2rgb/yuv_rgb_std.c",

    "src/video/dummy/SDL_nullevents.c",
    "src/video/dummy/SDL_nullframebuffer.c",
    "src/video/dummy/SDL_nullvideo.c",

    "src/video/offscreen/SDL_offscreenevents.c",
    "src/video/offscreen/SDL_offscreenframebuffer.c",
    "src/video/offscreen/SDL_offscreenvideo.c",
    "src/video/offscreen/SDL_offscreenwindow.c",
    "src/video/offscreen/SDL_offscreenopengles.c",
    "src/video/offscreen/SDL_offscreenvulkan.c",
};

const windows_src_files = [_][]const u8{
    "src/audio/directsound/SDL_directsound.c",
    "src/audio/wasapi/SDL_wasapi.c",
    "src/audio/wasapi/SDL_wasapi_win32.c",

    "src/camera/mediafoundation/SDL_camera_mediafoundation.c",

    "src/core/windows/SDL_hid.c",
    "src/core/windows/SDL_immdevice.c",
    "src/core/windows/SDL_windows.c",
    "src/core/windows/SDL_xinput.c",
    "src/core/windows/pch.c",
    "src/core/windows/pch_cpp.cpp",
    // "src/core/gdk/SDL_gdk.cpp",

    "src/dialog/windows/SDL_windowsdialog.c",

    "src/filesystem/windows/SDL_sysfilesystem.c",
    "src/filesystem/windows/SDL_sysfsops.c",

    "src/gpu/d3d11/SDL_gpu_d3d11.c",
    "src/gpu/d3d12/SDL_gpu_d3d12.c",

    "src/haptic/windows/SDL_dinputhaptic.c",
    "src/haptic/windows/SDL_windowshaptic.c",

    "src/hidapi/windows/hid.c",
    "src/hidapi/windows/hidapi_descriptor_reconstruct.c",
    "src/hidapi/windows/pp_data_dump/pp_data_dump.c",

    "src/joystick/windows/SDL_dinputjoystick.c",
    "src/joystick/windows/SDL_rawinputjoystick.c",
    "src/joystick/windows/SDL_windows_gaming_input.c",
    "src/joystick/windows/SDL_windowsjoystick.c",
    "src/joystick/windows/SDL_xinputjoystick.c",

    "src/loadso/windows/SDL_sysloadso.c",

    "src/locale/windows/SDL_syslocale.c",

    "src/main/windows/SDL_sysmain_runapp.c",

    "src/misc/windows/SDL_sysurl.c",

    "src/power/windows/SDL_syspower.c",

    "src/process/windows/SDL_windowsprocess.c",

    "src/render/direct3d/SDL_render_d3d.c",
    "src/render/direct3d/SDL_shaders_d3d.c",
    "src/render/direct3d11/SDL_render_d3d11.c",
    "src/render/direct3d11/SDL_shaders_d3d11.c",
    "src/render/direct3d12/SDL_render_d3d12.c",
    "src/render/direct3d12/SDL_shaders_d3d12.c",

    "src/sensor/windows/SDL_windowssensor.c",

    "src/thread/windows/SDL_syscond_cv.c",
    "src/thread/windows/SDL_sysmutex.c",
    "src/thread/windows/SDL_sysrwlock_srw.c",
    "src/thread/windows/SDL_syssem.c",
    "src/thread/windows/SDL_systhread.c",
    "src/thread/windows/SDL_systls.c",

    // NOTE: Looks like some platforms will require these,
    //       but they can't be globally used in the 'generic'
    //       source list because they'll conflict with their
    //       platform specific implementation.
    "src/thread/generic/SDL_syscond.c",
    "src/thread/generic/SDL_sysrwlock.c",
    "src/thread/generic/SDL_syssem.c",
    "src/thread/generic/SDL_systhread.c",
    "src/thread/generic/SDL_systls.c",

    "src/time/windows/SDL_systime.c",

    "src/timer/windows/SDL_systimer.c",

    "src/video/windows/SDL_windowsclipboard.c",
    "src/video/windows/SDL_windowsevents.c",
    "src/video/windows/SDL_windowsframebuffer.c",
    "src/video/windows/SDL_windowsgameinput.c",
    "src/video/windows/SDL_windowskeyboard.c",
    "src/video/windows/SDL_windowsmessagebox.c",
    "src/video/windows/SDL_windowsmodes.c",
    "src/video/windows/SDL_windowsmouse.c",
    "src/video/windows/SDL_windowsopengl.c",
    "src/video/windows/SDL_windowsopengles.c",
    "src/video/windows/SDL_windowsrawinput.c",
    "src/video/windows/SDL_windowsshape.c",
    "src/video/windows/SDL_windowsvideo.c",
    "src/video/windows/SDL_windowsvulkan.c",
    "src/video/windows/SDL_windowswindow.c",
};

const linux_src_files = [_][]const u8{
    "src/camera/v4l2/SDL_camera_v4l2.c",

    "src/core/linux/SDL_evdev.c",
    "src/core/linux/SDL_evdev_capabilities.c",
    "src/core/linux/SDL_evdev_kbd.c",
    "src/core/linux/SDL_sandbox.c",
    "src/core/linux/SDL_threadprio.c",
    "src/core/unix/SDL_appid.c",
    "src/core/unix/SDL_poll.c",

    // Requires D-BUS development package
    // "src/core/linux/SDL_dbus.c",
    // "src/core/linux/SDL_fcitx.c",
    // "src/core/linux/SDL_ibus.c",
    // "src/core/linux/SDL_ime.c",
    // "src/core/linux/SDL_system_theme.c",
    // "src/core/linux/SDL_udev.c",

    "src/dialog/unix/SDL_portaldialog.c",
    "src/dialog/unix/SDL_unixdialog.c",
    "src/dialog/unix/SDL_zenitydialog.c",

    "src/filesystem/unix/SDL_sysfilesystem.c",
    "src/filesystem/posix/SDL_sysfsops.c",

    "src/haptic/linux/SDL_syshaptic.c",

    // Requires libudev development package
    // "src/hidapi/linux/hid.c",

    "src/joystick/linux/SDL_sysjoystick.c",
    "src/joystick/dummy/SDL_sysjoystick.c",

    "src/loadso/dlopen/SDL_sysloadso.c",

    "src/locale/unix/SDL_syslocale.c",

    "src/misc/unix/SDL_sysurl.c",

    "src/power/linux/SDL_syspower.c",

    "src/process/posix/SDL_posixprocess.c",

    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_sysrwlock.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",

    "src/time/unix/SDL_systime.c",

    "src/timer/unix/SDL_systimer.c",

    "src/video/kmsdrm/SDL_kmsdrmdyn.c",
    "src/video/kmsdrm/SDL_kmsdrmevents.c",
    "src/video/kmsdrm/SDL_kmsdrmmouse.c",
    "src/video/kmsdrm/SDL_kmsdrmopengles.c",
    "src/video/kmsdrm/SDL_kmsdrmvideo.c",
    "src/video/kmsdrm/SDL_kmsdrmvulkan.c",
    "src/video/x11/SDL_x11clipboard.c",
    "src/video/x11/SDL_x11dyn.c",
    "src/video/x11/SDL_x11events.c",
    "src/video/x11/SDL_x11framebuffer.c",
    "src/video/x11/SDL_x11keyboard.c",
    "src/video/x11/SDL_x11messagebox.c",
    "src/video/x11/SDL_x11modes.c",
    "src/video/x11/SDL_x11mouse.c",
    "src/video/x11/SDL_x11opengl.c",
    "src/video/x11/SDL_x11opengles.c",
    "src/video/x11/SDL_x11pen.c",
    "src/video/x11/SDL_x11settings.c",
    "src/video/x11/SDL_x11shape.c",
    "src/video/x11/SDL_x11touch.c",
    "src/video/x11/SDL_x11video.c",
    "src/video/x11/SDL_x11vulkan.c",
    "src/video/x11/SDL_x11window.c",
    "src/video/x11/SDL_x11xfixes.c",
    "src/video/x11/SDL_x11xinput2.c",
    "src/video/x11/edid-parse.c",
    "src/video/x11/xsettings-client.c",
};

const darwin_src_files = [_][]const u8{
    "src/audio/aaudio/SDL_aaudio.c",
    "src/haptic/darwin/SDL_syshaptic.c",
    "src/hidapi/mac/hid.c",
    "src/joystick/darwin/SDL_iokitjoystick.c",
    "src/power/macos/SDL_syspower.c",
    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_sysrwlock.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
    "src/time/unix/SDL_systime.c",
    "src/timer/unix/SDL_systimer.c",
    "src/process/posix/SDL_posixprocess.c",
    "src/core/unix/SDL_appid.c",
    "src/core/unix/SDL_poll.c",
    "src/locale/unix/SDL_syslocale.c",
    "src/misc/unix/SDL_sysurl.c",
};

const objective_c_src_files = [_][]const u8{
    "src/audio/coreaudio/SDL_coreaudio.m",
    "src/camera/coremedia/SDL_camera_coremedia.m",
    "src/dialog/cocoa/SDL_cocoadialog.m",
    "src/filesystem/cocoa/SDL_sysfilesystem.m",
    "src/gpu/metal/SDL_gpu_metal.m",
    "src/hidapi/ios/hid.m",
    // "src/hidapi/testgui/mac_support_cocoa.m",
    "src/joystick/apple/SDL_mfijoystick.m",
    "src/locale/macos/SDL_syslocale.m",
    "src/main/ios/SDL_sysmain_callbacks.m",
    "src/misc/ios/SDL_sysurl.m",
    "src/misc/macos/SDL_sysurl.m",
    "src/power/uikit/SDL_syspower.m",
    "src/render/metal/SDL_render_metal.m",
    "src/sensor/coremotion/SDL_coremotionsensor.m",
    "src/video/cocoa/SDL_cocoaclipboard.m",
    "src/video/cocoa/SDL_cocoaevents.m",
    "src/video/cocoa/SDL_cocoakeyboard.m",
    "src/video/cocoa/SDL_cocoamessagebox.m",
    "src/video/cocoa/SDL_cocoametalview.m",
    "src/video/cocoa/SDL_cocoamodes.m",
    "src/video/cocoa/SDL_cocoamouse.m",
    "src/video/cocoa/SDL_cocoaopengl.m",
    "src/video/cocoa/SDL_cocoaopengles.m",
    "src/video/cocoa/SDL_cocoapen.m",
    "src/video/cocoa/SDL_cocoashape.m",
    "src/video/cocoa/SDL_cocoavideo.m",
    "src/video/cocoa/SDL_cocoavulkan.m",
    "src/video/cocoa/SDL_cocoawindow.m",
    "src/video/uikit/SDL_uikitappdelegate.m",
    "src/video/uikit/SDL_uikitclipboard.m",
    "src/video/uikit/SDL_uikitevents.m",
    "src/video/uikit/SDL_uikitmessagebox.m",
    "src/video/uikit/SDL_uikitmetalview.m",
    "src/video/uikit/SDL_uikitmodes.m",
    "src/video/uikit/SDL_uikitopengles.m",
    "src/video/uikit/SDL_uikitopenglview.m",
    "src/video/uikit/SDL_uikitvideo.m",
    "src/video/uikit/SDL_uikitview.m",
    "src/video/uikit/SDL_uikitviewcontroller.m",
    "src/video/uikit/SDL_uikitvulkan.m",
    "src/video/uikit/SDL_uikitwindow.m",
};

const ios_src_files = [_][]const u8{};

const emscripten_src_files = [_][]const u8{
    "src/audio/emscripten/SDL_emscriptenaudio.c",
    "src/camera/emscripten/SDL_camera_emscripten.c",
    "src/filesystem/emscripten/SDL_sysfilesystem.c",
    "src/joystick/emscripten/SDL_sysjoystick.c",
    "src/locale/emscripten/SDL_syslocale.c",
    "src/main/emscripten/SDL_sysmain_callbacks.c",
    "src/main/emscripten/SDL_sysmain_runapp.c",
    "src/misc/emscripten/SDL_sysurl.c",
    "src/power/emscripten/SDL_syspower.c",
    "src/video/emscripten/SDL_emscriptenevents.c",
    "src/video/emscripten/SDL_emscriptenframebuffer.c",
    "src/video/emscripten/SDL_emscriptenmouse.c",
    "src/video/emscripten/SDL_emscriptenopengles.c",
    "src/video/emscripten/SDL_emscriptenvideo.c",

    "src/timer/unix/SDL_systimer.c",
    "src/loadso/dlopen/SDL_sysloadso.c",
    "src/audio/disk/SDL_diskaudio.c",
    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",
    "src/sensor/dummy/SDL_dummysensor.c",

    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
};

const unknown_src_files = [_][]const u8{};

const static_headers = [_][]const u8{
    "SDL3/SDL.h",
    "SDL3/SDL_assert.h",
    "SDL3/SDL_atomic.h",
    "SDL3/SDL_audio.h",
    "SDL3/SDL_begin_code.h",
    "SDL3/SDL_bits.h",
    "SDL3/SDL_blendmode.h",
    "SDL3/SDL_camera.h",
    "SDL3/SDL_clipboard.h",
    "SDL3/SDL_close_code.h",
    "SDL3/SDL_copying.h",
    "SDL3/SDL_cpuinfo.h",
    "SDL3/SDL_dialog.h",
    "SDL3/SDL_egl.h",
    "SDL3/SDL_endian.h",
    "SDL3/SDL_error.h",
    "SDL3/SDL_events.h",
    "SDL3/SDL_filesystem.h",
    "SDL3/SDL_gamepad.h",
    "SDL3/SDL_gpu.h",
    "SDL3/SDL_guid.h",
    "SDL3/SDL_haptic.h",
    "SDL3/SDL_hidapi.h",
    "SDL3/SDL_hints.h",
    "SDL3/SDL_init.h",
    "SDL3/SDL_intrin.h",
    "SDL3/SDL_iostream.h",
    "SDL3/SDL_joystick.h",
    "SDL3/SDL_keyboard.h",
    "SDL3/SDL_keycode.h",
    "SDL3/SDL_loadso.h",
    "SDL3/SDL_locale.h",
    "SDL3/SDL_log.h",
    "SDL3/SDL_main.h",
    "SDL3/SDL_main_impl.h",
    "SDL3/SDL_messagebox.h",
    "SDL3/SDL_metal.h",
    "SDL3/SDL_misc.h",
    "SDL3/SDL_mouse.h",
    "SDL3/SDL_mutex.h",
    "SDL3/SDL_oldnames.h",
    "SDL3/SDL_opengl.h",
    "SDL3/SDL_opengl_glext.h",
    "SDL3/SDL_opengles.h",
    "SDL3/SDL_opengles2.h",
    "SDL3/SDL_opengles2_gl2.h",
    "SDL3/SDL_opengles2_gl2ext.h",
    "SDL3/SDL_opengles2_gl2platform.h",
    "SDL3/SDL_opengles2_khrplatform.h",
    "SDL3/SDL_pen.h",
    "SDL3/SDL_pixels.h",
    "SDL3/SDL_platform.h",
    "SDL3/SDL_platform_defines.h",
    "SDL3/SDL_power.h",
    "SDL3/SDL_process.h",
    "SDL3/SDL_properties.h",
    "SDL3/SDL_rect.h",
    "SDL3/SDL_render.h",
    "SDL3/SDL_revision.h",
    "SDL3/SDL_scancode.h",
    "SDL3/SDL_sensor.h",
    "SDL3/SDL_stdinc.h",
    "SDL3/SDL_storage.h",
    "SDL3/SDL_surface.h",
    "SDL3/SDL_system.h",
    "SDL3/SDL_test.h",
    "SDL3/SDL_test_assert.h",
    "SDL3/SDL_test_common.h",
    "SDL3/SDL_test_compare.h",
    "SDL3/SDL_test_crc32.h",
    "SDL3/SDL_test_font.h",
    "SDL3/SDL_test_fuzzer.h",
    "SDL3/SDL_test_harness.h",
    "SDL3/SDL_test_log.h",
    "SDL3/SDL_test_md5.h",
    "SDL3/SDL_test_memory.h",
    "SDL3/SDL_thread.h",
    "SDL3/SDL_time.h",
    "SDL3/SDL_timer.h",
    "SDL3/SDL_touch.h",
    "SDL3/SDL_version.h",
    "SDL3/SDL_video.h",
    "SDL3/SDL_vulkan.h",
    "build_config/SDL_build_config.h",
    "build_config/SDL_build_config_android.h",
    "build_config/SDL_build_config_emscripten.h",
    "build_config/SDL_build_config_ios.h",
    "build_config/SDL_build_config_macos.h",
    "build_config/SDL_build_config_minimal.h",
    "build_config/SDL_build_config_ngage.h",
    "build_config/SDL_build_config_windows.h",
    "build_config/SDL_build_config_wingdk.h",
    "build_config/SDL_build_config_xbox.h",
};

const SdlOption = struct {
    name: []const u8,
    desc: []const u8,
    default: bool,
    // SDL configs affect the public SDL_config.h header file. Any values
    // should occur in a header file in the include directory.
    sdl_configs: []const []const u8,
    // C Macros are similar to SDL configs but aren't present in the public
    // headers and only affect the SDL implementation.  None of the values
    // should occur in the include directory.
    c_macros: []const []const u8 = &.{},
    src_files: []const []const u8,
    system_libs: []const []const u8,
};

const global_options = [_]SdlOption{
    .{
        .name = "render_driver_software",
        .desc = "enable the software render driver",
        .default = true,
        .sdl_configs = &.{},
        .c_macros = &.{"SDL_VIDEO_RENDER_SW"},
        .src_files = &.{
            "src/render/software/SDL_blendfillrect.c",
            "src/render/software/SDL_blendline.c",
            "src/render/software/SDL_blendpoint.c",
            "src/render/software/SDL_drawline.c",
            "src/render/software/SDL_drawpoint.c",
            "src/render/software/SDL_render_sw.c",
            "src/render/software/SDL_rotate.c",
            "src/render/software/SDL_triangle.c",
        },
        .system_libs = &.{},
    },
    .{
        .name = "render_driver_ogl",
        .desc = "enable the opengl render driver",
        .default = true,
        .sdl_configs = &.{"SDL_VIDEO_RENDER_OGL"},
        .src_files = &.{
            "src/render/opengl/SDL_render_gl.c",
            "src/render/opengl/SDL_shaders_gl.c",
        },
        .system_libs = &.{},
    },
    .{
        .name = "render_driver_vulkan",
        .desc = "enable the vulkan render driver",
        .default = true,
        .sdl_configs = &.{"SDL_VIDEO_RENDER_VULKAN"},
        .src_files = &.{
            "src/render/vulkan/SDL_render_vulkan.c",
            "src/render/vulkan/SDL_shaders_vulkan.c",
        },
        .system_libs = &.{},
    },
    .{
        .name = "render_driver_gpu",
        .desc = "enable the opengl render driver",
        .default = true,
        .sdl_configs = &.{"SDL_VIDEO_RENDER_GPU"},
        .src_files = &.{
            "src/render/gpu/SDL_pipeline_gpu.c",
            "src/render/gpu/SDL_render_gpu.c",
            "src/render/gpu/SDL_shaders_gpu.c",
        },
        .system_libs = &.{},
    },
    .{
        .name = "render_driver_ogl_es2",
        .desc = "enable the opengl es2 render driver",
        .default = true,
        .sdl_configs = &.{"SDL_VIDEO_RENDER_OGL_ES2"},
        .src_files = &.{
            "src/render/opengles2/SDL_render_gles2.c",
            "src/render/opengles2/SDL_shaders_gles2.c",
        },
        .system_libs = &.{},
    },
};

const linux_options = [_]SdlOption{
    .{
        .name = "video_driver_x11",
        .desc = "enable the x11 video driver",
        .default = true,
        .sdl_configs = &.{
            "SDL_VIDEO_DRIVER_X11",
            "SDL_VIDEO_DRIVER_X11_SUPPORTS_GENERIC_EVENTS",
        },
        .src_files = &.{},
        .system_libs = &.{ "x11", "xext" },
    },
    .{
        .name = "audio_driver_pulse",
        .desc = "enable the pulse audio driver",
        .default = false,
        .sdl_configs = &.{"SDL_AUDIO_DRIVER_PULSEAUDIO"},
        .src_files = &.{"src/audio/pulseaudio/SDL_pulseaudio.c"},
        .system_libs = &.{"pulse"},
    },
    .{
        .name = "audio_driver_alsa",
        .desc = "enable the alsa audio driver",
        .default = false,
        .sdl_configs = &.{"SDL_AUDIO_DRIVER_ALSA"},
        .src_files = &.{"src/audio/alsa/SDL_alsa_audio.c"},
        .system_libs = &.{"alsa"},
    },
};

fn applyOption(
    comptime option: *const SdlOption,
    lib: *std.Build.Step.Compile,
    upstream_root: std.Build.LazyPath,
) void {
    lib.addCSourceFiles(.{ .root = upstream_root, .files = option.src_files });
    for (option.system_libs) |lib_name| {
        lib.linkSystemLibrary(lib_name);
    }
}

fn applyOptions(
    comptime options: []const SdlOption,
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream_root: std.Build.LazyPath,
) void {
    inline for (options) |option| {
        const enabled = if (b.option(bool, option.name, option.desc)) |o| o else option.default;
        for (option.c_macros) |name| {
            lib.defineCMacro(name, if (enabled) "1" else "0");
        }
        if (enabled) {
            applyOption(&option, lib, upstream_root);
        }
    }
}

fn applyOptionsWithConfig(
    comptime options: []const SdlOption,
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    upstream_root: std.Build.LazyPath,
    config_header: *std.Build.Step.ConfigHeader,
) void {
    inline for (options) |option| {
        const enabled = if (b.option(bool, option.name, option.desc)) |o| o else option.default;
        for (option.c_macros) |name| {
            lib.defineCMacro(name, if (enabled) "1" else "0");
        }
        for (option.sdl_configs) |config| {
            config_header.values.put(config, .{ .int = if (enabled) 1 else 0 }) catch @panic("OOM");
        }
        if (enabled) {
            applyOption(&option, lib, upstream_root);
        }
    }
}
