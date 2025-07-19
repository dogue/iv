package iv

import "core:fmt"
import "core:encoding/ini"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

// map keys configured in `binds.ini` to actions and raylib keys
load_binds :: proc(state: ^State, allocator := context.allocator) {
    cfg, _ := os.read_entire_file("config.ini", allocator) // TODO: error handling
    defer delete(cfg)
    it := ini.iterator_from_string(string(cfg))

    for k, v in ini.iterate(&it) {
        // non-bind options
        if opt, ok := fmt.string_to_enum_value(Option, k); ok {
            state.config.options[opt] = strings.clone(v, allocator)
            continue
        }

        action, k_ok := fmt.string_to_enum_value(Action, k)
        bind, v_ok := fmt.string_to_enum_value(rl.KeyboardKey, v)

        // TODO: *good* error handling
        if !k_ok || !v_ok {
            panic("fix binds")
        }

        // state.config.binds[action] = bind
    }
}

Key_Bind :: struct {
    key: rl.KeyboardKey,
    shift: bool,
    alt: bool,
    ctrl: bool,
}

load_binds2 :: proc(state: ^State, allocator := context.allocator, deallocate_after_load := true) {
    config, _, ok := ini.load_map_from_path("config.ini", allocator)
    if !ok {
        panic("failed to load config.ini")
    }
    // NOTE: Since we are going to process the strings in the map and reduce them to concrete types, we can optionally deallocate the map before returning.
    defer if deallocate_after_load do ini.delete_map(config)

    for section, contents in config {
        switch section {
        case "options":

        case "keys":
            for k, v in contents {
                action, bind, ok := parse_key_bind(k, v, allocator)
                if !ok {
                    fmt.eprintfln("Error: Invalid key bind: \"%s = %s\"", k, v)
                }

                state.config.binds2[action] = bind
            }

        case: // NOTE: I'm choosing to ignore unexpected sections for now. Will revisit and reconsider at a later time.
        }
    }
}

parse_key_bind :: proc(k, v: string, allocator := context.temp_allocator) -> (action: Action, bind: Key_Bind, ok: bool) {
    map_key := strings.trim_space(k)
    map_val := strings.trim_space(v)

    // Ensure the provided map key string matches the Ada casing of our enum variants and attempt to convert to an enum value.
    map_key_normalized := strings.to_ada_case(map_key)
    action = fmt.string_to_enum_value(Action, map_key_normalized) or_return

    // Check for modifiers in the map value string (such as: ctrl+q)
    if strings.index(map_val, "+") > -1 {
        parts := strings.split(map_val, "+")

        // These options are few enough to not warrant the allocations necessary for `strings.to_upper` or `.to_lower`.
        switch strings.trim_space(parts[0]) {
        case "shift", "SHIFT", "Shift": bind.shift = true
        case "alt", "ALT", "Alt":       bind.alt = true
        case "ctrl", "CTRL", "Ctrl":    bind.ctrl = true
        case: return action, bind, false
        }

        // TODO: We have not yet guaranteed that the key side of the key/value pair from the map is fully valid. For now we YOLO.
        map_val = strings.trim_space(parts[1])
    }

    // Raylib uses upper case enum variants
    map_val_upper := strings.to_upper(map_val, allocator)
    bind.key = fmt.string_to_enum_value(rl.KeyboardKey, map_val_upper) or_return

    return action, bind, true
}
