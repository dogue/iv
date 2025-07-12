package sump

import "core:mem"
import "core:fmt"

track: mem.Tracking_Allocator

start :: proc() -> mem.Allocator {
    mem.tracking_allocator_init(&track, context.allocator)
    return mem.tracking_allocator(&track)
}

end :: proc() {
    if len(track.allocation_map) > 0 {
        for _, entry in track.allocation_map {
            fmt.eprintfln("%v leaked %v bytes", entry.location, entry.size)
        }
    }

    if len(track.bad_free_array) > 0 {
        for entry in track.bad_free_array {
            fmt.eprintfln("%v bad free at %v", entry.location, entry.memory)
        }
    }

    mem.tracking_allocator_destroy(&track)
}
