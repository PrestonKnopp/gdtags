## Generates a nim friendly api using cPlugin.
##
## A thing to note is how cPlugin stores symbols in a HashSet. Nim allows
## overloaded procs, but cPlugin does not. For example:
##
## .. code-block::
##   # Defined in nim:
##   proc delete(parser: Parser)
##   proc delete(treeCursor: TreeCursor)
##   # Defined in c
##   parser_delete(Parser* parser)
##   tree_cursor_delete(TreeCursor* treeCursor)
##
## This works around that with the -d:tsGenWriteIgnoredProcs flag. When the flag
## is passed this will output all proc definitions that would be ignored by
## cPlugin. Then the developer has to manually add these procs to the end of
## this file.
##
##
## This file is included in the build step of treesitter.nim and requires no
## manual execution. However, you can run the following command to generate
## treesitter manually.
##
## Run command:
## nim --hints:off --compileOnly c src/tsgen.nim > src/generated_treesitter.nim
##
## And to write ignored procs to /tmp/ignoredProcs:
## nim --hints:off --compileOnly c -d:tsGenWriteIgnoredProcs src/tsgen.nim > src/generated_treesitter.nim
import os
import nimterop/[cimport, build]

const treeSitterDir = getProjectCacheDir("treesitter")
const tsLib = treeSitterDir/"lib"

cPlugin:
  import strutils, sets, unicode, sequtils
  import nimterop/build

  var typeSet: HashSet[string]
  var types: seq[seq[string]]

  var procSet: HashSet[string]
  var ignoredProcs: seq[string]

  when defined(tsGenWriteIgnoredProcs):
    addQuitProc proc () {.noconv.} =
      # Since cPlugin stores symbols in a HashSet overloaded symbols will be ignored.
      # We have to manually add these overloaded procs. See bottom of file.
      var f = open("/tmp/ignoredProcs", fmWrite)
      f.writeLine ignoredProcs.join("\n")
      f.close()

  proc splitByCaps(s: string): seq[string] =
    var i, n = 0
    while true:
      if i == -1: break
      n = s.find({'A'..'Z'}, i.succ)
      if n == -1:
        result.add s.substr(i)
      else:
        result.add s.substr(i, n.pred)
      i = n
  
  proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =
    var o = $sym.name
    var n = $sym.name

    if n.startsWith("ts_tree_cursor"):
      # See bottom of file
      sym.name = ""
      return
      
    if n == "ts_node_string":
      sym.name = "toLisp"
      return

    if n.startsWith("TS"):
      n = replace("" & n, "TS", "")
      if n notin typeSet:
        typeSet.incl n
        types.add n.splitByCaps
      sym.name = n
    elif n.startsWith("ts_"):
      n = n.replace("ts_", "")
      var sp = n.split("_")
      if sp[sp.high] == "new":
        sym.name = "new" & sp[0..sp.high.pred].mapIt(it.title).join("")
        return
      var maxMunch = (idx: 0, count: 0)
      for i, names in types:
        if names.len > sp.len:
          continue
        var count = 0
        for j in 0..<names.len:
          let name = names[j]
          let symPart = sp[j]
          if name.cmpIgnoreCase(symPart) == 0:
            count.inc
        if count > maxMunch.count:
          maxMunch.count = count
          maxMunch.idx = i
      # echo sp, maxMunch, " ", types[maxMunch.idx]
      for i in 0..<maxMunch.count:
        sp.delete(0)
      sp = sp.mapIt(it.title)
      sp[0] = sp[0].toLower
      n = sp.join("")

      if n.contains("Null"):
        n = n.replace("Null", "Nil")
      
      # ts_node_type() -> name()
      if n == "type":
        n = "name"
      
      if sym.kind == nskProc:
        if n in procSet:
          ignoredProcs.add n & ", " & o
        else:
          procSet.incl n
      
      sym.name = n

static:
  cDebug()

cImport tsLib/"include/tree_sitter/api.h", flags = "--no-comments"
# cImport tsLib/"include/tree_sitter/api.h"

static:
  echo """

# These overload procs are ignored since cPlugin stores symbols in a HashSet.
# We can echo them out to be added to the generated file.
proc delete*(self: ptr Tree) {.importc: "ts_tree_delete", header: headerapi, cdecl.}
proc delete*(self: ptr Query) {.importc: "ts_query_delete", header: headerapi, cdecl.}
proc delete*(self: ptr QueryCursor) {.importc: "ts_query_cursor_delete", header: headerapi, cdecl.}
proc language*(self: ptr Tree): ptr Language {.importc: "ts_tree_language", header: headerapi, cdecl.}
proc edit*(self: ptr Node, input: ptr InputEdit) {.importc: "ts_node_edit", header: headerapi, cdecl.}
  """

  echo """

# TreeCursor has `var` param semantics.
proc newTreeCursor*(a1: Node): TreeCursor {.importc: "ts_tree_cursor_new", header: headerapi, cdecl.}
proc delete*(self: var TreeCursor) {.importc: "ts_tree_cursor_delete", header: headerapi, cdecl.}
proc reset*(self: var TreeCursor, node: Node) {.importc: "ts_tree_cursor_reset", header: headerapi, cdecl.}
proc copy*(self: var TreeCursor): TreeCursor {.importc: "ts_tree_cursor_copy", header: headerapi, cdecl.}
proc currentNode*(a1: var TreeCursor): Node {.importc: "ts_tree_cursor_current_node", header: headerapi, cdecl.}
proc currentFieldName*(a1: var TreeCursor): cstring {.importc: "ts_tree_cursor_current_field_name", header: headerapi, cdecl.}
proc currentFieldId*(a1: var TreeCursor): FieldId {.importc: "ts_tree_cursor_current_field_id", header: headerapi, cdecl.}
proc gotoParent*(a1: var TreeCursor): bool {.importc: "ts_tree_cursor_goto_parent", header: headerapi, cdecl.}
proc gotoNextSibling*(a1: var TreeCursor): bool {.importc: "ts_tree_cursor_goto_next_sibling", header: headerapi, cdecl.}
proc gotoFirstChild*(a1: var TreeCursor): bool {.importc: "ts_tree_cursor_goto_first_child", header: headerapi, cdecl.}
proc gotoFirstChildForByte*(a1: var TreeCursor, a2: uint32): int64 {.importc: "ts_tree_cursor_goto_first_child_for_byte", header: headerapi, cdecl.}
  """
