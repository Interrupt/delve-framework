import os, gen_zig

tasks = [
    [ '../sokol_gp.h',             'sgp_',      [] ],
    [ '../sokol_log.h',            'slog_',     [] ],
    [ '../sokol_gfx.h',            'sg_',       [] ],
    [ '../sokol_app.h',            'sapp_',     [] ],
    [ '../sokol_glue.h',           'sapp_sg',   ['sg_'] ],
    [ '../sokol_time.h',           'stm_',      [] ],
    [ '../sokol_audio.h',          'saudio_',   [] ],
    [ '../sokol_gl.h',             'sgl_',      ['sg_'] ],
    [ '../sokol_debugtext.h',      'sdtx_',     ['sg_'] ],
    [ '../sokol_shape.h',          'sshape_',   ['sg_'] ],
]

# Zig
gen_zig.prepare()
for task in tasks:
    [c_header_path, main_prefix, dep_prefixes] = task
    gen_zig.gen(c_header_path, main_prefix, dep_prefixes)