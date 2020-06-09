import os
import nimterop/[cimport, build]

const treeSitterGdscriptDir = getProjectCacheDir("treesittergdscript")
const tsSrc = treeSitterGdscriptDir/"src"

static:
  # cDebug()
  # cDisableCaching()

  gitPull("https://github.com/PrestonKnopp/tree-sitter-gdscript", treeSitterGdscriptDir, """
src/*.h
src/*.c
src/*.cc
src/tree_sitter/parser.h
""", "v1.0.0")

  writeFile(tsSrc/"api.h", """
#include "tree_sitter/parser.h"
const TSLanguage *tree_sitter_gdscript();
""")

when defined(macosx):
  {.passL: "-lc++".}
elif defined(linux):
  {.passL: "-lstdc++"}

import ./treesitter

cIncludeDir(tsSrc)

cCompile(tsSrc/"parser.c")
cCompile(tsSrc/"scanner.cc")

proc newGdscript*(): ptr Language {.importc: "tree_sitter_gdscript", header: tsSrc/"api.h".}
