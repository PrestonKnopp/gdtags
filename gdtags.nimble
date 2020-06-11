# Package

version       = "0.1.0"
author        = "PrestonKnopp"
description   = "Generate ctags in universal-ctags or json format for GDScript."
license       = "MIT"
srcDir        = "src"
bin           = @["gdtags"]

# Dependencies

requires "nim >= 1.2.0"
requires "nimterop 0.4.4"
