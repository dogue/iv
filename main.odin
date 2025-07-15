package iv

import "core:mem"
import "core:encoding/ini"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"
import magic "libmagic-odin"
import rl "vendor:raylib"
import "sump"

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

Key_Map :: [Action]rl.KeyboardKey
Option_Map :: [Option]string

Config :: struct {
    binds: Key_Map,
    options: Option_Map
}

State :: struct {
    mode: Mode,
    image: rl.Image,
    texture: rl.Texture2D,
    pos: rl.Vector2,
    scale: f32,
    config: Config,
    hints_enabled: bool,
    hints: [Mode]string,
    hint_font: rl.Font,
}

init_state :: proc(allocator := context.allocator) -> State {
    s := State {
        hints_enabled = true,
        scale = 1,
    }
    load_binds(&s, allocator)
    return s
}

deinit_state :: proc(s: ^State) {
    for &o in s.config.options {
        delete(o)
    }
}

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

        state.config.binds[action] = bind
    }
}

// validate font mime type and load from embedded data
load_font :: proc(mime_type: cstring) -> rl.Font {
    suffix: cstring
    switch mime_type {
    case "font/sfnt": suffix = ".ttf"
    case "application/vnd.ms-opentype": suffix = ".otf"
    case:
        // TODO: consider unconditionally embedding the fallback font and loading it here with a warning instead
        fmt.eprintfln("Error: This application was compiled with an unsupported font type. Supported types are OTF and TTF. The compiled font is %q.", FONT)
        os.exit(1)
    }

    return rl.LoadFontFromMemory(suffix, raw_data(FONT_DATA), i32(len(FONT_DATA)), 16, nil, 0)
}

is_supported_filetype :: proc(mime_type: cstring) -> bool {
    for t in SUPPORTED_FILETYPES {
        if t == mime_type do return true
    }
    return false
}

load_image :: proc(filename: cstring) -> (img: rl.Image, tex: rl.Texture2D) {
    img = rl.LoadImage(filename)
    tex = rl.LoadTextureFromImage(img)
    rl.SetTextureFilter(tex, .TRILINEAR)
    return img, tex
}

calc_scaled_position :: proc(v: State) -> (pos: rl.Vector2) {
    sw := f32(rl.GetRenderWidth()) + v.pos.x
    sh := f32(rl.GetRenderHeight()) + v.pos.y
    tw := f32(v.texture.width)
    th := f32(v.texture.height)
    pos.x = sw / 2 - (tw * v.scale) / 2
    pos.y = sh / 2 - (th * v.scale) / 2
    return pos
}

calc_autofit_scale :: proc(w, h: f32) -> f32 {
    scale_w := f32(rl.GetRenderWidth()) / w
    scale_h := f32(rl.GetRenderHeight()) / h
    return min(scale_w, scale_h)
}

calc_autofill_scale :: proc(w, h: f32) -> f32 {
    scale_w := f32(rl.GetRenderWidth()) / w
    scale_h := f32(rl.GetRenderHeight()) / h
    return max(scale_w, scale_h)
}

// normal mode actions
handle_normal_cmd :: proc(s: ^State) {
    if rl.IsKeyPressed(s.config.binds[.Mode_Move]) {
        s.mode = .Move
        return
    }

    if rl.IsKeyPressed(s.config.binds[.Mode_Size]) {
        s.mode = .Size
        return
    }
}

// move mode actions
handle_move_cmd :: proc(s: ^State) {
    if rl.IsKeyPressed(s.config.binds[.Move_Left]) {
        s.pos.x -= 10
    }

    if rl.IsKeyPressed(s.config.binds[.Move_Right]) {
        s.pos.x += 10
    }

    if rl.IsKeyPressed(s.config.binds[.Move_Down]) {
        s.pos.y += 10
    }

    if rl.IsKeyPressed(s.config.binds[.Move_Up]) {
        s.pos.y -= 10
    }

    // TODO: consider a more descriptive name for this action (resetting image position to center)
    if rl.IsKeyPressed(s.config.binds[.Reset]) {
        reset_view_pos(s)
    }

    if rl.IsKeyPressed(s.config.binds[.Mode_Normal]) {
        s.mode = .Normal
    }
}

reset_view_pos :: proc(v: ^State) {
    w := f32(rl.GetRenderWidth()) / 2 - f32(v.texture.width)
    h := f32(rl.GetRenderHeight()) / 2 - f32(v.texture.height)
    v.pos = {w, h}
}

// size mode actions
handle_size_cmd :: proc(s: ^State) {
    if rl.IsKeyPressed(s.config.binds[.Zoom_In]) {
        s.scale += 0.1
    }

    if rl.IsKeyPressed(s.config.binds[.Zoom_Out]) {
        s.scale -= 0.1
    }

    if rl.IsKeyPressed(s.config.binds[.Fit_Width]) {
        s.scale = f32(rl.GetRenderWidth()) / f32(s.texture.width)
    }

    if rl.IsKeyPressed(s.config.binds[.Fit_Height]) {
        s.scale = f32(rl.GetRenderHeight()) / f32(s.texture.height)
    }

    if rl.IsKeyPressed(s.config.binds[.Auto_Fit]) {
        s.scale = calc_autofit_scale(f32(s.texture.width), f32(s.texture.height))
    }

    if rl.IsKeyPressed(s.config.binds[.Auto_Fill]) {
        s.scale = calc_autofill_scale(f32(s.texture.width), f32(s.texture.height))
    }

    if rl.IsKeyPressed(s.config.binds[.Mode_Normal]) {
        s.mode = .Normal
    }
}

// TODO: consider making background/text colors configurable
draw_hints :: proc(s: State, hint_text: cstring) {
    w := rl.GetRenderWidth()
    h := rl.GetRenderHeight()

    // background rect
    rl.DrawRectangle(0, h - 20, w, 20, {18, 18, 18, 255})
    rl.DrawTextEx(s.hint_font, hint_text, {6, f32(h - 18)}, 16, 0, rl.WHITE)
}

main :: proc() {
    when ODIN_DEBUG {
        context.allocator = sump.start()
        defer sump.end()
    }

    cookie := magic.open(magic.MIME_TYPE)
    if cookie == nil {
        fmt.eprintln("Error allocating cookie")
        return
    }
    defer magic.close(cookie)

    if magic.load(cookie, nil) != 0 {
        fmt.eprintfln("Error loading magic database: %s", magic.error(cookie))
        return
    }

    if len(os.args) < 2 {
        fmt.println("Usage: iv <jpg/png image file>")
        // TODO: print *good* help
        return
    }

    filename := strings.clone_to_cstring(os.args[1])
    defer delete(filename)
    result := magic.file(cookie, filename)

    if result == nil {
        fmt.eprintfln("Error opening file: %s\n", magic.error(cookie))
        return
    }

    if !is_supported_filetype(result) {
        fmt.eprintfln("Error: unsupported file type: %s", result)
        return
    }

    rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .WINDOW_MAXIMIZED})
    rl.InitWindow(0, 0, fmt.ctprintf("iv - %s", filename))
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))


    state := init_state()
    defer deinit_state(&state)

    state.image, state.texture = load_image(filename)
    rl.SetExitKey(state.config.binds[.Quit])

    font_mime_type := magic.buffer(cookie, raw_data(FONT_DATA), uintptr(len(FONT_DATA))) // get embedded font MIME type (OTF/TTF are supported)
    state.hint_font = load_font(font_mime_type)

    first_fit := false
    frame_count := 0

    invert_zoom, parse_ok := strconv.parse_bool(state.config.options[.Invert_Mouse_Zoom])
    if !parse_ok {
        fmt.eprintfln("Failed to parse boolean value for option 'Invert_Mouse_Zoom'. Got: %q", state.config.options[.Invert_Mouse_Zoom])
    }

    for !rl.WindowShouldClose() {
        // run auto fit after the first frame when RenderWidth/RenderHeight are reliably populated
        if !first_fit && frame_count >= 1 {
            state.scale = calc_autofit_scale(f32(state.texture.width), f32(state.texture.height))
            first_fit = true
        }

        if rl.IsMouseButtonDown(.LEFT) {
            // NOTE: unsure why doubling the delta is needed, but it is in order to have the texture move at the same speed as the cursor
            rl.HideCursor()
            state.pos += rl.GetMouseDelta() * 2
        } else {
            rl.ShowCursor()
        }

        // reduce zoom speed when shift held
        base_zoom_speed := f32(rl.IsKeyDown(.LEFT_SHIFT) ? 0.01 : 0.1) * (invert_zoom ? -1 : 1)

        // make zoom speed scale with image zoom for smoother changes
        zoom_speed := base_zoom_speed * state.scale
        state.scale = clamp(state.scale + rl.GetMouseWheelMove() * zoom_speed, 0.05, 100)

        if rl.IsKeyPressed(state.config.binds[.Toggle_Hints]) {
            state.hints_enabled = !state.hints_enabled
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.BLACK)
        rl.DrawTextureEx(state.texture, calc_scaled_position(state), 0, state.scale, rl.WHITE)

        switch state.mode {
        case .Normal:
            handle_normal_cmd(&state)
            if state.hints_enabled {
                draw_hints(state, fmt.ctprintf(
                    "[NOR] %s: move | %s: size | %s: toggle hints | %s: quit",
                    state.config.binds[.Mode_Move],
                    state.config.binds[.Mode_Size],
                    state.config.binds[.Toggle_Hints],
                    state.config.binds[.Quit]
                ))
            }

        case .Move:
            handle_move_cmd(&state)
            if state.hints_enabled {
                draw_hints(state, fmt.ctprintf(
                    "[MOV] %s: left | %s: right | %s: up | %s: down",
                    state.config.binds[.Move_Left],
                    state.config.binds[.Move_Right],
                    state.config.binds[.Move_Up],
                    state.config.binds[.Move_Down],
                ))
            }

        case .Size:
            handle_size_cmd(&state)
            if state.hints_enabled {
                draw_hints(state, fmt.ctprintf(
                    "[SIZE] %s: zoom in | %s: zoom out | %s: fit width | %s: fit height | %s: auto fit | %s: auto fill",
                    state.config.binds[.Zoom_In],
                    state.config.binds[.Zoom_Out],
                    state.config.binds[.Fit_Width],
                    state.config.binds[.Fit_Height],
                    state.config.binds[.Auto_Fit],
                    state.config.binds[.Auto_Fill],
                ))
            }
        }

        if state.hints_enabled {
            text := fmt.ctprintf("Zoom: %d%%", int(state.scale * 100))
            w := rl.MeasureTextEx(state.hint_font, text, 16, 0)
            rl.DrawTextEx(state.hint_font, text, {f32(rl.GetRenderWidth()) - w.x - 6, f32(rl.GetRenderHeight() - 18)}, 16, 0, rl.WHITE)
        }

        // we can stop counting frames once the first fit is done
        if !first_fit do frame_count += 1
    }
}
