iv - image viewer

This repo contains an in-development simple image viewer. As development is ongoing, many things are subject to change. Below is a brief rundown of the project.

Current features:
- Currently supports JPG and PNG files. This limitation is for keeping early development simple. More formats to come later.
- Uses a modal input style akin to vim. Keys can be rebound in `binds.ini`. These binds are loaded at runtime. Key designations must match the corresponding variant in Raylib's `KeyboardKey` enum. (See included `binds.ini` for examples).
- Features on-screen key hints that can be toggled on or off. The hints font can be set at compile time with `-define:FONT=<font_file>`. OTF and TTF are supported. FiraCode-Regular is provided as a fallback font.
- Scaling actions include automatic best fit, automatic fill (with cropping), fit to image width or height, and manual zooming in/out.
- Movement keys for adjusting image position within the window.

Possible future features (TBD):
- Open directory/multiple files with key actions to cycle through files.
- Support for animated images (GIF).
- Image rotation.

If you decide to try this software and encounter any bugs and/or interface pain points, please feel free to open an issue here.
