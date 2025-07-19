package iv

import "core:mem"
import "core:encoding/ini"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"
import magic "libmagic-odin"
import "sump"
import sdl "vendor:sdl2"
import img "vendor:sdl2/image"
import ttf "vendor:sdl2/ttf"

SDL_FLAGS: sdl.InitFlags = { .VIDEO }
IMG_FLAGS: img.InitFlags = { .JPG, .PNG, .TIF, .WEBP }
WIN_FLAGS: sdl.WindowFlags = { .SHOWN, .RESIZABLE }
RENDER_FLAGS: sdl.RendererFlags = { .ACCELERATED }

FONT :: #config(FONT, "FiraCode-Regular.ttf")
FONT_DATA :: #load(FONT)

SUPPORTED_FILETYPES :: [?]cstring{
    "image/jpeg",
    "image/png",
}

Mode :: enum {
    Normal,
    Move,
    Size,
}

Action :: enum {
    Mode_Normal,
    Mode_Move,
    Mode_Size,
    Toggle_Hints,
    Quit,
    Zoom_In,
    Zoom_Out,
    Fit_Width,
    Fit_Height,
    Auto_Fit,
    Auto_Fill,
    Move_Left,
    Move_Right,
    Move_Up,
    Move_Down,
    Reset,
}

Option :: enum {
    Invert_Mouse_Zoom,
}

// Key_Map :: [Action]rl.KeyboardKey
Key_Map2 :: [Action]Key_Bind
Option_Map :: [Option]string

Config :: struct {
    // binds: Key_Map,
    binds2: Key_Map2,
    options: Option_Map
}

Image :: struct {
    texture: ^sdl.Texture,
    scale: f32,
    pos: [2]f32,
    // The original image dimensions are stored to use later as a base size when scaling
    size: [2]f32,
}

Status_Bar :: struct {
    enabled: bool,
    text: cstring,
    font: ^ttf.Font,
}

State :: struct {
    mode: Mode,
    window: ^sdl.Window,
    renderer: ^sdl.Renderer,
    image: Image,
    config: Config,
    status: Status_Bar,
}

init_state :: proc(allocator := context.allocator) -> State {
    s := State {
        status = Status_Bar {
            enabled = true,
        }
    }
    load_binds(&s, allocator)
    return s
}

deinit_state :: proc(s: ^State) {
    for &o in s.config.options {
        delete(o)
    }
}

init_sdl :: proc(s: ^State) -> (ok: bool) {
    if sdl.Init(SDL_FLAGS) != 0 {
        fmt.eprintfln("Error initializing SDL2: %s", sdl.GetError())
        return false
    }

    if img.Init(IMG_FLAGS) != IMG_FLAGS {
        fmt.eprintfln("Error initializing SDL2_img: %s", img.GetError())
        return false
    }

    if ttf.Init() != 0 {
        fmt.eprintfln("Error initializing SDL2_ttf: %s", ttf.GetError())
        return false
    } 

    s.window = sdl.CreateWindow(
        "iv",
        sdl.WINDOWPOS_UNDEFINED,
        sdl.WINDOWPOS_UNDEFINED,
        0,
        0,
        WIN_FLAGS,
    )
    if s.window == nil {
        fmt.eprintfln("Error create window: %s", sdl.GetError())
        return false
    }

    s.renderer = sdl.CreateRenderer(s.window, -1, RENDER_FLAGS)
    if s.renderer == nil {
        fmt.eprintfln("Error creating renderer: %s", sdl.GetError())
        return false
    }

    return true
}

load_font :: proc(s: ^State) {
    font_rwop := sdl.RWFromConstMem(raw_data(FONT_DATA), i32(len(FONT_DATA)))
    s.status.font = ttf.OpenFontRW(font_rwop, freesrc = false, ptsize = 15)
}

load_image :: proc(s: ^State, filename: cstring) -> (ok: bool) {
    s.image.texture = img.LoadTexture(s.renderer, filename)
    if s.image.texture == nil {
        fmt.eprintfln("Error loading image: %s", img.GetError())
        return false
    }

    w, h: i32
    if sdl.QueryTexture(s.image.texture, nil, nil, &w, &h) != 0 {
        fmt.eprintfln("Error querying texture dimensions: %s", sdl.GetError())
        return false
    }
    s.image.size.xy = {f32(w), f32(h)}

    if sdl.SetTextureScaleMode(s.image.texture, .Best) != 0 {
        fmt.eprintfln("Error setting texture scale mode: %s", img.GetError())
        return false
    }

    // auto fit image on initial load
    set_scale_by_mode(s, .Fit)
    return true
}

// Returns an `FRect` with W/H scaled up or down from the orinal image dimensions
get_scaled_rect :: proc(s: ^State) -> (rect: sdl.FRect) {
    rect.w = s.image.size.x * s.image.scale 
    rect.h = s.image.size.y * s.image.scale
    return rect
}

Scaling_Mode :: enum {
    // Scale to match larger axis, ensuring the entire image is visible
    Fit,
    // Scale to match smaller axis, enduring the entire window is filled
    Fill,
    // Scale to original image size
    Real,
}

set_scale_by_mode :: proc(s: ^State, mode: Scaling_Mode) -> (ok: bool) {
    // Query rendering contraints and calculate scaling factors for width and height
    w_, h_: i32
    if sdl.GetRendererOutputSize(s.renderer, &w_, &h_) != 0 {
        fmt.eprintfln("Error getting render output size: %s", sdl.GetError())
        return false
    }
    w := f32(w_) / s.image.size.x
    h := f32(h_) / s.image.size.y

    switch mode {
    case .Fit: s.image.scale = min(w, h)
    case .Fill: s.image.scale = max(w, h)
    case .Real: s.image.scale = 1
    }

    return true
}

// normal mode actions
// handle_normal_cmd :: proc(s: ^State) {
//     if rl.IsKeyPressed(s.config.binds[.Mode_Move]) {
//         s.mode = .Move
//         return
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Mode_Size]) {
//         s.mode = .Size
//         return
//     }
// }

// move mode actions
// handle_move_cmd :: proc(s: ^State) {
//     if rl.IsKeyPressed(s.config.binds[.Move_Left]) {
//         s.pos.x -= 10
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Move_Right]) {
//         s.pos.x += 10
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Move_Down]) {
//         s.pos.y += 10
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Move_Up]) {
//         s.pos.y -= 10
//     }
//
//     // TODO: consider a more descriptive name for this action (resetting image position to center)
//     if rl.IsKeyPressed(s.config.binds[.Reset]) {
//         reset_view_pos(s)
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Mode_Normal]) {
//         s.mode = .Normal
//     }
// }

// size mode actions
// handle_size_cmd :: proc(s: ^State) {
//     if rl.IsKeyPressed(s.config.binds[.Zoom_In]) {
//         s.scale += 0.1
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Zoom_Out]) {
//         s.scale -= 0.1
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Fit_Width]) {
//         s.scale = f32(rl.GetRenderWidth()) / f32(s.texture.width)
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Fit_Height]) {
//         s.scale = f32(rl.GetRenderHeight()) / f32(s.texture.height)
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Auto_Fit]) {
//         s.scale = calc_autofit_scale(f32(s.texture.width), f32(s.texture.height))
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Auto_Fill]) {
//         s.scale = calc_autofill_scale(f32(s.texture.width), f32(s.texture.height))
//     }
//
//     if rl.IsKeyPressed(s.config.binds[.Mode_Normal]) {
//         s.mode = .Normal
//     }
// }

// TODO: consider making background/text colors configurable
// draw_hints :: proc(s: State, hint_text: cstring) {
//     w := rl.GetRenderWidth()
//     h := rl.GetRenderHeight()
//
//     // background rect
//     rl.DrawRectangle(0, h - 20, w, 20, {18, 18, 18, 255})
//     rl.DrawTextEx(s.hint_font, hint_text, {6, f32(h - 18)}, 16, 0, rl.WHITE)
// }

draw_status_bar :: proc(s: ^State) -> (ok: bool) {
    sdl.SetRenderDrawColor(s.renderer, 0x1a, 0x1a, 0x1a, 0xff)

    status_bar_rect: sdl.Rect
    if sdl.GetRendererOutputSize(s.renderer, &status_bar_rect.w, &status_bar_rect.h) != 0 {
        fmt.eprintfln("Error getting render output size: %s", sdl.GetError())
        return false
    }
    status_bar_rect.y = status_bar_rect.h - 20
    status_bar_rect.h = 20

    if sdl.RenderFillRect(s.renderer, &status_bar_rect) != 0 {
        fmt.eprintfln("Error drawing status bar region: %s", sdl.GetError())
        return false
    } 

    text_surface := ttf.RenderText_Blended(s.status.font, s.status.text, {255, 255, 255, 255})
    if text_surface == nil {
        fmt.eprintfln("Error creating status text surface: %s", sdl.GetError())
        return false
    }
    defer sdl.FreeSurface(text_surface)

    text_texture := sdl.CreateTextureFromSurface(s.renderer, text_surface)
    if text_texture == nil {
        fmt.eprintfln("Error creating texture from status text surface: %s", sdl.GetError())
        return false
    }
    defer sdl.DestroyTexture(text_texture)

    text_rect := status_bar_rect
    text_rect.x += 6
    if ttf.MeasureUTF8(s.status.font, s.status.text, status_bar_rect.w, &text_rect.w, nil) != 0 {
        fmt.eprintfln("Error measuring status text: %s", ttf.GetError())
        return false
    }

    if sdl.RenderCopy(s.renderer, text_texture, nil, &text_rect) != 0 {
        fmt.eprintfln("Error copying status bar data to renderer: %s", sdl.GetError())
        return false
    }

    return true
}

key_down :: proc(s: ^State, e: sdl.KeyboardEvent) {
    #partial switch e.keysym.scancode {
    case .Q:
        evt := sdl.Event{ type = .QUIT }
        sdl.PushEvent(&evt)

    case .S: s.status.enabled = !s.status.enabled
    }
}

app_main :: proc(s: ^State) {
    event: sdl.Event
    for {
        for sdl.PollEvent(&event) {
            #partial switch event.type {
            case .QUIT: return
            case .KEYDOWN: key_down(s, event.key)
            }
        }

        sdl.SetRenderDrawColor(s.renderer, 0, 0, 0 ,0)
        sdl.RenderClear(s.renderer)

        dst_rect := get_scaled_rect(s)
        dst_rect.x = s.image.pos.x
        dst_rect.y = s.image.pos.y
        sdl.RenderCopyF(s.renderer, s.image.texture, nil, &dst_rect)

        s.status.text = "Hellope"
        if s.status.enabled {
            if !draw_status_bar(s) {
                // disable status bar drawing if we run into errors
                // might be stupid - we'll see
                s.status.enabled = false
            }
        }

        sdl.RenderPresent(s.renderer)
        // TODO: calculate delay based on frametime delta
        sdl.Delay(16)
    }
}

main :: proc() {
    when ODIN_DEBUG {
        context.allocator = sump.start()
        defer sump.end()
    }

    // cookie := magic.open(magic.MIME_TYPE)
    // if cookie == nil {
    //     fmt.eprintln("Error allocating cookie")
    //     return
    // }
    // defer magic.close(cookie)
    //
    // if magic.load(cookie, nil) != 0 {
    //     fmt.eprintfln("Error loading magic database: %s", magic.error(cookie))
    //     return
    // }

    if len(os.args) < 2 {
        fmt.println("Usage: iv <jpg/png image file>")
        // TODO: print *good* help
        return
    }

    filename := strings.clone_to_cstring(os.args[1])
    defer delete(filename)
    // result := magic.file(cookie, filename)

    // if result == nil {
    //     fmt.eprintfln("Error opening file: %s\n", magic.error(cookie))
    //     return
    // }
    //
    // if !is_supported_filetype(result) {
    //     fmt.eprintfln("Error: unsupported file type: %s", result)
    //     return
    // }

    // rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .WINDOW_MAXIMIZED})
    // rl.InitWindow(0, 0, fmt.ctprintf("iv - %s", filename))
    // rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))


    state := init_state()
    defer deinit_state(&state)

    // just quit on error for now
    if !init_sdl(&state) do return
    if !load_image(&state, filename) do return
    load_font(&state)

    app_main(&state)
    // state.image, state.texture = load_image(filename)
    // rl.SetExitKey(state.config.binds[.Quit])

    // font_mime_type := magic.buffer(cookie, raw_data(FONT_DATA), uintptr(len(FONT_DATA))) // get embedded font MIME type (OTF/TTF are supported)
    // state.hint_font = load_font(font_mime_type)

    // first_fit := false
    // frame_count := 0

    // invert_zoom, parse_ok := strconv.parse_bool(state.config.options[.Invert_Mouse_Zoom])
    // if !parse_ok {
        // fmt.eprintfln("Failed to parse boolean value for option 'Invert_Mouse_Zoom'. Got: %q", state.config.options[.Invert_Mouse_Zoom])
    // }

//     for !rl.WindowShouldClose() {
//         // run auto fit after the first frame when RenderWidth/RenderHeight are reliably populated
//         if !first_fit && frame_count >= 1 {
//             state.scale = calc_autofit_scale(f32(state.texture.width), f32(state.texture.height))
//             first_fit = true
//         }
//
//         if rl.IsMouseButtonDown(.LEFT) {
//             // NOTE: unsure why doubling the delta is needed, but it is in order to have the texture move at the same speed as the cursor
//             rl.HideCursor()
//             state.pos += rl.GetMouseDelta() * 2
//         } else {
//             rl.ShowCursor()
//         }
//
//         // reduce zoom speed when shift held
//         base_zoom_speed := f32(rl.IsKeyDown(.LEFT_SHIFT) ? 0.01 : 0.1) * (invert_zoom ? -1 : 1)
//
//         // make zoom speed scale with image zoom for smoother changes
//         zoom_speed := base_zoom_speed * state.scale
//         state.scale = clamp(state.scale + rl.GetMouseWheelMove() * zoom_speed, 0.05, 100)
//
//         if rl.IsKeyPressed(state.config.binds[.Toggle_Hints]) {
//             state.hints_enabled = !state.hints_enabled
//         }
//
//         rl.BeginDrawing()
//         defer rl.EndDrawing()
//
//         rl.ClearBackground(rl.BLACK)
//         rl.DrawTextureEx(state.texture, calc_scaled_position(state), 0, state.scale, rl.WHITE)
//
//         switch state.mode {
//         case .Normal:
//             handle_normal_cmd(&state)
//             if state.hints_enabled {
//                 draw_hints(state, fmt.ctprintf(
//                     "[NOR] %s: move | %s: size | %s: toggle hints | %s: quit",
//                     state.config.binds[.Mode_Move],
//                     state.config.binds[.Mode_Size],
//                     state.config.binds[.Toggle_Hints],
//                     state.config.binds[.Quit]
//                 ))
//             }
//
//         case .Move:
//             handle_move_cmd(&state)
//             if state.hints_enabled {
//                 draw_hints(state, fmt.ctprintf(
//                     "[MOV] %s: left | %s: right | %s: up | %s: down",
//                     state.config.binds[.Move_Left],
//                     state.config.binds[.Move_Right],
//                     state.config.binds[.Move_Up],
//                     state.config.binds[.Move_Down],
//                 ))
//             }
//
//         case .Size:
//             handle_size_cmd(&state)
//             if state.hints_enabled {
//                 draw_hints(state, fmt.ctprintf(
//                     "[SIZE] %s: zoom in | %s: zoom out | %s: fit width | %s: fit height | %s: auto fit | %s: auto fill",
//                     state.config.binds[.Zoom_In],
//                     state.config.binds[.Zoom_Out],
//                     state.config.binds[.Fit_Width],
//                     state.config.binds[.Fit_Height],
//                     state.config.binds[.Auto_Fit],
//                     state.config.binds[.Auto_Fill],
//                 ))
//             }
//         }
//
//         if state.hints_enabled {
//             text := fmt.ctprintf("Zoom: %d%%", int(state.scale * 100))
//             w := rl.MeasureTextEx(state.hint_font, text, 16, 0)
//             rl.DrawTextEx(state.hint_font, text, {f32(rl.GetRenderWidth()) - w.x - 6, f32(rl.GetRenderHeight() - 18)}, 16, 0, rl.WHITE)
//         }
//
//         // we can stop counting frames once the first fit is done
//         if !first_fit do frame_count += 1
//     }
}
