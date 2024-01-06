const std = @import("std");
const zaudio = @import("zaudio");
const debug = @import("../debug.zig");
const modules = @import("../modules.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

// zaudio miniaudio engine
var zaudio_engine: ?*zaudio.Engine = null;

// list of all the loaded sounds, so that they can be garbage collected when done
var loaded_sounds: std.AutoArrayHashMap(u64, LoadedSound) = undefined;
var next_sound_idx: u64 = 0;

/// A wrapper around a loaded sound
pub const LoadedSound = struct {
    handle: u64,
    zaudio_sound: ?*zaudio.Sound,
    ready_for_cleanup: bool = false,
};

/// A sound that is loaded and can be adjusted
pub const Sound = struct {
    handle: u64,

    // if this was loaded as streaming
    is_streaming: bool = false,

    /// Checks if this sound is still alive
    pub fn isAlive(self: *Sound) bool {
        var found = loaded_sounds.get(self.handle);
        if(found != null) {
            return found.ready_for_cleanup;
        }
        return true;
    }

    /// Marks this sound as being ready for cleanup
    pub fn requestDestroy(self: *Sound) void {
        var found = loaded_sounds.getPtr(self.handle);
        if(found) |loaded_sound| {
            loaded_sound.ready_for_cleanup = true;
        }
    }

    /// Whether this sound needs to be garbage collected
    pub fn needsCleanup(self: *Sound) bool {
        var found = loaded_sounds.getPtr(self.handle);
        if(found) |loaded_sound| {
            return loaded_sound.ready_for_cleanup;
        }

        return false;
    }

    /// Starts playing this sound
    pub fn start(self: *Sound) void {
        if(getZaudioSound(self.handle)) |sound| {
            sound.start() catch {
                debug.log("Could not start sound!", .{});
                return;
            };
        }
    }

    /// Stops this sound
    pub fn stop(self: *Sound) void {
        if(getZaudioSound(self.handle)) |sound| {
            sound.stop() catch {
                debug.log("Could not stop sound!", .{});
                return;
            };
        }
    }

    /// Makes this sound loop, default is to not
    pub fn setLooping(self: *Sound, looping: bool) void {
        if(getZaudioSound(self.handle)) |sound|
            sound.setLooping(looping);
    }

    /// Sets the volume for this sound
    pub fn setVolume(self: *Sound, volume: f32) void {
        if(getZaudioSound(self.handle)) |sound|
            sound.setVolume(volume);
    }

    /// Sets the pitch for this sound
    pub fn setPitch(self: *Sound, pitch: f32) void {
        if(getZaudioSound(self.handle)) |sound|
            sound.setPitch(pitch);
    }

    /// Sets the panning for this sound
    pub fn setPan(self: *Sound, pan: f32) void {
        if(getZaudioSound(self.handle)) |sound|
            sound.setPan(pan);
    }

    /// Sets the position of this sound
    pub fn setPosition(self: *Sound, pos: [3]f32) void {
        if(getZaudioSound(self.handle)) |sound| {
                // Make sure this sound is spatialized! Will be absolute by default
                if(sound.getPositioning() != zaudio.Positioning.relative)
                    sound.setPositioning(zaudio.Positioning.relative);

                sound.setPosition(pos);
        }
    }

    /// Sets the velocity of this sound
    pub fn setVelocity(self: *Sound, vel: [3]f32) void {
        if(getZaudioSound(self.handle)) |sound|
            sound.setVelocity(vel);
    }

    /// Sets the direction of this sound
    pub fn setDirection(self: *Sound, dir: [3]f32) void {
        if(getZaudioSound(self.handle)) |sound|
            sound.setDirection(dir);
    }

    /// Gets if the sound is playing
    pub fn getIsPlaying(self: *Sound) bool {
        if(getZaudioSound(self.handle)) |sound|
            return sound.isPlaying();

        return false;
    }

    /// Whether or not the sound has played all the way through
    pub fn getIsDone(self: *Sound) bool {
        if(getZaudioSound(self.handle)) |sound| {
            return sound.isAtEnd();
        }

        return true;
    }

    /// Gets if the sound is looping
    pub fn getLooping(self: *Sound) bool {
        if(getZaudioSound(self.handle)) |sound| {
            return sound.getLooping();
        }
        return false;
    }

    /// Gets the current volume
    pub fn getVolume(self: *Sound) f32 {
        if(getZaudioSound(self.handle)) |sound|
            return sound.getVolume();

        return 1.0;
    }

    /// Gets the current pitch
    pub fn getPitch(self: *Sound) f32 {
        if(getZaudioSound(self.handle)) |sound|
            return sound.getPitch();

        return 1.0;
    }

    /// Gets the current pan
    pub fn getPan(self: *Sound) f32 {
        if(getZaudioSound(self.handle)) |sound|
            return sound.getPan();

        return 1.0;
    }
};

/// Registers the audio subsystem as a module
pub fn registerModule() !void {
    const audioSubsystem = modules.Module {
        .name = "audio_subystem",
        .tick_fn = on_tick,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(audioSubsystem);
}

/// Starts the audio subsystem
pub fn init() !void {
    debug.log("Audio system initializing", .{});

    zaudio.init(allocator);
    zaudio_engine = try zaudio.Engine.create(null);

    loaded_sounds = std.AutoArrayHashMap(u64, LoadedSound).init(allocator);

    // Register this subystem as a module to get tick events
    try registerModule();
}

/// Stops and cleans up the audio subsystem
pub fn deinit() void {
    loaded_sounds.deinit();

    if(zaudio_engine) |engine|
        engine.destroy();

    zaudio.deinit();
}

/// Loads and plays a piece of music
pub fn playMusic(filename: [:0]const u8, volume: f32, loop: bool) ?Sound {
    var sound = loadSound(filename, true) catch {
        debug.log("Could not load music file! ({s})", .{ filename });
        return null;
    };

    // Just do one handle lookup here
    if(getZaudioSound(sound.handle)) |zaudio_sound| {
        zaudio_sound.setVolume(volume);
        zaudio_sound.setLooping(loop);
        zaudio_sound.start() catch {
            sound.requestDestroy();
        };
    }

    return sound;
}

/// Loads and plays a sound effect
pub fn playSound(filename: [:0]const u8, volume: f32) ?Sound {
    var sound = loadSound(filename, false) catch {
        debug.log("Could not load sound file! ({s})", .{ filename });
        return null;
    };

    // Just do one handle lookup here
    if(getZaudioSound(sound.handle)) |zaudio_sound| {
        zaudio_sound.setVolume(volume);
        zaudio_sound.start() catch {
            sound.requestDestroy();
        };
    }

    return sound;
}

/// Loads a sound. Streaming is best for longer samples like music
pub fn loadSound(filename: [:0]const u8, stream: bool) !Sound {
    const zaudio_sound = try zaudio_engine.?.createSoundFromFile(
        filename,
        .{ .flags = .{ .stream = stream, .async_load = true } },
    );

    errdefer zaudio_sound.destroy();

    const handle = next_sound_idx;
    next_sound_idx += 1;

    try loaded_sounds.put(handle, LoadedSound{.handle = handle, .zaudio_sound = zaudio_sound});
    return Sound { .handle = next_sound_idx - 1, .is_streaming = stream };
}

/// Sets the position of our listener for spatial audio
pub fn setListenerPosition(pos: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerPosition(0, pos);
    }
}

/// Sets the direction of our listener for spatial audio
pub fn setListenerDirection(dir: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerDirection(0, dir);
    }
}

/// Sets the velocity of our listener for spatial audio
pub fn setListenerVelocity(vel: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerVelocity(0, vel);
    }
}

/// Sets the 'up' value for the listener
pub fn setListenerWorldUp(up: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerWorldUp(0, up);
    }
}

/// Enables spatial audio
pub fn enableSpatialAudio(enabled: bool) void {
    if(zaudio_engine) |engine| {
        engine.setListenerEnabled(0, enabled);
    }
}

/// App lifecycle on_tick
pub fn on_tick(tick: u64) void {
    _ = tick;

    var it = loaded_sounds.iterator();
    while(it.next()) |sound| {
        var needs_destroy = sound.value_ptr.ready_for_cleanup;

        if(!needs_destroy) {
            if(sound.value_ptr.zaudio_sound) |zaudio_sound| {
                needs_destroy = zaudio_sound.isAtEnd();
            } else {
                // How did a null zaudio sound get in here?
                debug.log("Cleaning up a zombie sound pointer!.", .{});
                needs_destroy = true;
            }
        }

        if(!needs_destroy)
            continue;

        // debug.log("Cleaning up sound.", .{});
        if(sound.value_ptr.zaudio_sound) |zaudio_sound| {
            zaudio_sound.destroy();
        }
        _ = loaded_sounds.swapRemove(sound.value_ptr.handle);

        // Only do one per-frame for now!
        // TODO: this sucks, remove more than one per-tick
        return;
    }
}

/// App lifecycle on_cleanup
pub fn on_cleanup() void {
    var it = loaded_sounds.iterator();
    while(it.next()) |sound| {
        if(sound.value_ptr.zaudio_sound) |zaudio_sound| {
            debug.log("Cleaning up sound.", .{});
            zaudio_sound.destroy();
        }
    }
}

/// Don't hold onto the result of this! It could be garbage collected
fn getZaudioSound(handle: u64) ?*zaudio.Sound {
    // Need to do a little dance to get the actual zaudio sound pointer
    var found = loaded_sounds.getPtr(handle);
    if(found) |loaded_sound| {
        if(loaded_sound.zaudio_sound) |sound|
            return sound;
    }

    return null;
}
