## Downloads tree-sitter and utf8proc and sets up its build configuration using
## nimterop.
##
## This file also builds and runs tsgen.nim to generate a nim friendly tree_sitter api.
import os, strutils
import nimterop/[cimport, build]

# Documentation:
#   https://github.com/nimterop/nimterop
#   https://nimterop.github.io/nimterop/cimport.html

const treeSitterDir = getProjectCacheDir("treesitter")
const tsLib = treeSitterDir/"lib"
const utf8PropDir = getProjectCacheDir("utf8proc")

static:

  # Print generated Nim to output
  # cDebug()
  # cDisableCaching()

  # Download C/C++ source code from a git repository
  gitPull("https://github.com/tree-sitter/tree-sitter", treeSitterDir, """
lib/include/*
lib/src/*
""", checkout = "0.16.5")

  gitPull("https://github.com/JuliaStrings/utf8proc", utf8PropDir, """
*.c
*.h
""")

  let
    stack = tsLib/"src"/"stack.c"
    parser = tsLib/"include"/"tree_sitter"/"parser.h"
    tparser = parser.replace("parser", "tparser")
    language = tsLib/"src"/"language.h"
    lexer = tsLib/"src"/"lexer.h"
    subtree = tsLib/"src"/"subtree.h"

  stack.writeFile(stack.readFile().replace("inline Stack", "Stack"))

  # parser.h
  mvFile(parser, tparser)
  language.writeFile(language.readFile().replace("parser.h", "tparser.h"))
  lexer.writeFile(lexer.readFile().replace("parser.h", "tparser.h"))
  subtree.writeFile(subtree.readFile().replace("parser.h", "tparser.h"))

# Specify include directories for gcc and Nim
cIncludeDir(tsLib/"include")
cIncludeDir(tsLib/"src")
cIncludeDir(utf8PropDir)

# Define global symbols
# cDefine("SYMBOL", "value")

# Any global compiler options
cDefine("UTF8PROC_STATIC")

# Any global linker options
# {.passL: "flags".}

# Compile in any common source code
cCompile(tsLib/"src"/"lib.c")

# Perform OS specific tasks
when defined(Linux):
  {.passC: "-std=c11".}

static:
  when not (defined(nimsuggest) or defined(nimcheck)):
    const genTsFile = currentSourcePath.parentDir/"generated_treesitter.nim"
    const tsGenNim = currentSourcePath.parentDir/"tsgen.nim"
    if not fileExists(genTsFile):
      let (output, _) = build.execAction("nim c --hints:off --compileOnly " & tsGenNim)
      writeFile genTsFile, output

include ./generated_treesitter.nim
