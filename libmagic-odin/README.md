# magic

Odin bindings for [`libmagic`](https://darwinsys.com/file/), the library behind the Unix `file` command.

This package allows you to identify file types and MIME types using `libmagic` directly from Odin.

## Requirements

- `libmagic` installed (usually via your system package manager)

## Usage

```odin
import "magic"
import "core:fmt"

main :: proc() {
    cookie := magic.open(magic.NONE)
    if cookie == nil {
        fmt.eprintln("Error allocating cookie")
        return
    }
    defer magic.close(cookie)

    if magic.load(cookie, nil) != 0 {
        fmt.eprintfln("Error loading magic database: %s", magic.error(cookie))
        return
    }

    result := magic.file(cookie, "example.png")

    if result == nil {
        fmt.eprintfln("Error: %s\n", magic.error(cookie))
        return
    }

    fmt.printfln("File type: %s", result)
}
```
