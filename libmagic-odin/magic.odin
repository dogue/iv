package magic

foreign import magic "system:magic"

@(link_prefix = "magic_")
foreign magic {
    open :: proc(flags: int) -> magic_t ---
    close :: proc(cookie: magic_t) ---

    getpath :: proc(magicfile: cstring, action: int) -> cstring ---
    file :: proc(cookie: magic_t, filename: cstring) -> cstring ---
    descriptor :: proc(cookie: magic_t, fd: int) -> cstring ---
    buffer :: proc(cookie: magic_t, buffer: rawptr, length: uintptr) -> cstring ---
    error :: proc(cookie: magic_t) -> cstring ---

    getflags :: proc(cookie: magic_t) -> int ---
    setflags :: proc(cookie: magic_t, flags: int) ---

    version :: proc() -> int ---
    load :: proc(cookie: magic_t, filename: cstring) -> int ---
    load_buffers :: proc(cookie: magic_t, buffers: [^]rawptr, sizes: [^]uintptr, nbuffers: uintptr) -> int ---

    compile :: proc(cookie: magic_t, filename: cstring) -> int ---
    check :: proc(cookie: magic_t, filename: cstring) -> int ---
    list :: proc(cookie: magic_t, filename: cstring) -> int ---
    errno :: proc(cookie: magic_t) -> int ---

    setparam :: proc(cookie: magic_t, param: Param, value: rawptr) -> int ---
    getparam :: proc(cookie: magic_t, param: Param, value: rawptr) -> int ---
}

magic_t :: distinct rawptr

NONE                :: 0x0000000 // no flags
DEBUG               :: 0x0000001 // turn on debugging
SYMLINK             :: 0x0000002 // follow symlinks
COMPRESS            :: 0x0000004 // check inside compressed files
DEVICES             :: 0x0000008 // look at the contents of devices
MIME_TYPE           :: 0x0000010 // return the MIME type
CONTINUE            :: 0x0000020 // return all matches
CHECK               :: 0x0000040 // print warnings to stderr
PRESERVE_ATIME      :: 0x0000080 // restore access time on exit
RAW                 :: 0x0000100 // don't convert unprintable characters
ERROR               :: 0x0000200 // handle ENOENT etc as real errors
MIME_ENCODING       :: 0x0000400 // return the MIME encoding
MIME                :: (MIME_TYPE | MIME_ENCODING)
APPLE               :: 0x0000800 // return the Apple creator/type

NO_CHECK_COMPRESS   :: 0x0001000 // don't check for compressed files
NO_CHECK_TAR        :: 0x0002000 // don't check for tar files
NO_CHECK_SOFT       :: 0x0004000 // don't check magic entries
NO_CHECK_APPTYPE    :: 0x0008000 // don't check application type
NO_CHECK_ELF        :: 0x0010000 // don't check for ELF details
NO_CHECK_TEXT       :: 0x0020000 // don't check for text files
NO_CHECK_CDF        :: 0x0040000 // don't check for CDF files
NO_CHECK_CSV        :: 0x0080000 // don't check for CSV files
NO_CHECK_TOKENS     :: 0x0100000 // don't check tokens
NO_CHECK_ENCODING   :: 0x0200000 // don't check text encodings
NO_CHECK_JSON       :: 0x0400000 // don't check for JSON files
NO_CHECK_SIMH       :: 0x0800000 // don't check for SIMH tape files

EXTENSION           :: 0x1000000 // return a /-separated list of extensions
COMPRESS_TRANSP     :: 0x2000000 // check inside compressed files but not report compression
NO_COMPRESS_FORK    :: 0x4000000 // don't allow decompression that needs to fork
NODESC              :: (EXTENSION | MIME | APPLE)

// no built-in tests; only consult the magic file
NO_CHECK_BUILTIN    :: (
    NO_CHECK_COMPRESS  |
    NO_CHECK_TAR       |
    NO_CHECK_APPTYPE   |
    NO_CHECK_ELF       |
    NO_CHECK_TEXT      |
    NO_CHECK_CSV       |
    NO_CHECK_CDF       |
    NO_CHECK_TOKENS    |
    NO_CHECK_ENCODING  |
    NO_CHECK_JSON      |
    NO_CHECK_SIMH      )

Param :: enum i32 {
    INDIR_MAX,
    NAME_MAX,
    ELF_PHNUM_MAX,
    ELF_SHNUM_MAX,
    ELF_NOTES_MAX,
    REGEX_MAX,
    BYTES_MAX,
    ENCODING_MAX,
    ELF_SHSIZE_MAX,
    MAGWARN_MAX,
}
