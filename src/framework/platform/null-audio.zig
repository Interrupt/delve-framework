const std = @import("std");
const zaudio = @import("zaudio");
const debug = @import("../debug.zig");
const mem = @import("../mem.zig");
const modules = @import("../modules.zig");

var allocator: std.mem.Allocator = undefined;

// list of all the loaded sounds, so that they can be garbage collected when done
var loaded_sounds: std.AutoArrayHashMap(u64, LoadedSound) = undefined;
var next_sound_idx: u64 = 0;

/// A wrapper around a loaded sound
pub const LoadedSound = struct {
    handle: u64,
    ready_for_cleanup: bool = false,
};

/// A sound that is loaded and can be adjusted
pub const Sound = struct {
    handle: u64,

    // if this was loaded as streaming
    is_streaming: bool = false,

    /// Checks if this sound is still alive
    pub fn isAlive(self: *Sound) bool {
        const found = loaded_sounds.get(self.handle);
        if (found != null)
            return found.ready_for_cleanup;

        return true;
    }

    /// Marks this sound as being ready for cleanup
    pub fn requestDestroy(self: *Sound) void {
        const found = loaded_sounds.getPtr(self.handle);
        if (found) |loaded_sound|
            loaded_sound.ready_for_cleanup = true;
    }

    /// Whether this sound needs to be garbage collected
    pub fn needsCleanup(self: *Sound) bool {
        const found = loaded_sounds.getPtr(self.handle);
        if (found) |loaded_sound|
            return loaded_sound.ready_for_cleanup;

        return false;
    }

    /// Starts playing this sound
    pub fn start(self: *Sound) void {
        _ = self;
    }

    /// Stops this sound
    pub fn stop(self: *Sound) void {
        _ = self;
    }

    /// Makes this sound loop, default is to not
    pub fn setLooping(self: *Sound, looping: bool) void {
        _ = looping;
        _ = self;
    }

    /// Sets the volume for this sound
    pub fn setVolume(self: *Sound, volume: f32) void {
        _ = volume;
        _ = self;
    }

    /// Sets the pitch for this sound
    pub fn setPitch(self: *Sound, pitch: f32) void {
        _ = pitch;
        _ = self;
    }

    /// Sets the panning for this sound
    pub fn setPan(self: *Sound, pan: f32) void {
        _ = pan;
        _ = self;
    }

    /// Sets the position of this sound
    pub fn setPosition(self: *Sound, pos: [3]f32, dir: [3]f32, vel: [3]f32) void {
        _ = vel;
        _ = dir;
        _ = pos;
        _ = self;
    }

    /// Gets if the sound is playing
    pub fn getIsPlaying(self: *Sound) bool {
        _ = self;
        return false;
    }

    /// Whether or not the sound has played all the way through
    pub fn getIsDone(self: *Sound) bool {
        _ = self;
        return true;
    }

    /// Gets if the sound is looping
    pub fn getLooping(self: *Sound) bool {
        _ = self;
        return false;
    }

    /// Gets the current volume
    pub fn getVolume(self: *Sound) f32 {
        _ = self;
        return 1.0;
    }

    /// Gets the current pitch
    pub fn getPitch(self: *Sound) f32 {
        _ = self;
        return 1.0;
    }

    /// Gets the current pan
    pub fn getPan(self: *Sound) f32 {
        _ = self;
        return 1.0;
    }
};

/// Registers the audio subsystem as a module
pub fn registerModule() !void {
    const audioSubsystem = modules.Module{
        .name = "subsystem.audio",
        .tick_fn = on_tick,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(audioSubsystem);
}

/// Starts the audio subsystem
pub fn init() !void {
    debug.log("Audio system initializing", .{});

    allocator = mem.getAllocator();

    loaded_sounds = std.AutoArrayHashMap(u64, LoadedSound).init(allocator);

    // Register this subystem as a module to get tick events
    try registerModule();
}

/// Stops and cleans up the audio subsystem
pub fn deinit() void {
    loaded_sounds.deinit();
}

/// Loads and plays a piece of music
pub fn playMusic(filename: [:0]const u8, volume: f32, loop: bool) ?Sound {
    _ = loop;
    _ = volume;
    const sound = loadSound(filename, true) catch {
        debug.log("Could not load music file! ({s})", .{filename});
        return null;
    };

    return sound;
}

/// Loads and plays a sound effect
pub fn playSound(filename: [:0]const u8, volume: f32) ?Sound {
    _ = volume;
    const sound = loadSound(filename, false) catch {
        debug.log("Could not load sound file! ({s})", .{filename});
        return null;
    };

    return sound;
}

/// Loads a sound. Streaming is best for longer samples like music
pub fn loadSound(filename: [:0]const u8, stream: bool) !Sound {
    _ = filename;
    const handle = next_sound_idx;
    next_sound_idx += 1;

    try loaded_sounds.put(handle, LoadedSound{ .handle = handle });
    return Sound{ .handle = next_sound_idx - 1, .is_streaming = stream };
}

/// Sets the position of our listener for spatial audio
pub fn setListenerPosition(pos: [3]f32) void {
    _ = pos;
}

/// Sets the direction of our listener for spatial audio
pub fn setListenerDirection(dir: [3]f32) void {
    _ = dir;
}

/// Sets the velocity of our listener for spatial audio
pub fn setListenerVelocity(vel: [3]f32) void {
    _ = vel;
}

/// Sets the 'up' value for the listener
pub fn setListenerWorldUp(up: [3]f32) void {
    _ = up;
}

/// Enables spatial audio
pub fn enableSpatialAudio(enabled: bool) void {
    _ = enabled;
}

/// App lifecycle on_tick
pub fn on_tick(delta: f32) void {
    _ = delta;

    var it = loaded_sounds.iterator();
    while (it.next()) |sound| {
        var needs_destroy = sound.value_ptr.ready_for_cleanup;

        if (needs_destroy) {
            // How did a null zaudio sound get in here?
            debug.log("Cleaning up a zombie sound pointer!.", .{});
            needs_destroy = true;
        }

        if (!needs_destroy)
            continue;

        _ = loaded_sounds.swapRemove(sound.value_ptr.handle);

        // Only do one per-frame for now!
        // TODO: this sucks, remove more than one per-tick
        return;
    }
}

/// App lifecycle on_cleanup
pub fn on_cleanup() !void {}
