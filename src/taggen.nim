import tables, strutils, strformat, algorithm, json

type
  FormatKind* = enum
    fJson, fCtags

  Field* = enum
    kind, lineNum,
    scopeKind, scope,
    signature, fEnum

  TagLineInfo = tuple
    path: string
    name: string
    pattern: string
    lineNum: int
    fields: OrderedTableRef[Field, string]

  TagGen* = ref object
    lines: seq[TagLineInfo]

const
  # These are modified from https://docs.ctags.io/en/latest/man/tags.5.html
  kindLongShortMap = {
    "variable": "v",
    "function": "f",
    "constant": "C",
    "enum": "e",
    "enumDef": "g",
    "class": "c",
    "signal": "s",
  }.toTable

  fieldNameMap: array[Field, string] = [
    kind: "kind",
    lineNum: "line",
    scopeKind: "scopeKind",
    scope: "scope",
    signature: "signature",
    fEnum: "enum",
  ]

proc add*(gen: TagGen, path, name, pattern: string, lineNum: int, fields: OrderedTableRef[Field, string]): void =
  gen.lines.add (path, name, pattern, lineNum, fields,)

proc genCtags(gen: TagGen): string =
  result = ""
  for line in gen.lines:
    result.add &"{line.name}\t{line.path}\t/^{line.pattern}$/;\""
    for k, v in line.fields:
      case k:
      of kind:
        let shortKind = kindLongShortMap[v]
        result.add &"\t{shortKind}"
      of scopeKind:
        let fieldName = v
        let fieldValue = line.fields[scope]
        result.add &"\t{fieldName}:{fieldValue}"
      of scope, lineNum:
        continue
      else:
        let fieldName = fieldNameMap[k]
        result.add &"\t{fieldName}:{v}"
    result.add &"\tline:{line.lineNum}"
    result.add "\n"

proc genJson(gen: TagGen): string =
  for line in gen.lines:
    var lineJson = %* {
      "_type": "tag",
      "name": line.name,
      "path": line.path,
      "pattern": "/^" & line.pattern & "$/",
      "line": line.lineNum,
    }
    for key, val in line.fields:
      if key == lineNum: continue
      lineJson[fieldNameMap[key]] = %* val
    result.add $lineJson & "\n"

proc gen*(gen: TagGen, formatKind: FormatKind, sorted: bool=true): string =
  if sorted:
    gen.lines.sort proc (x, y: TagLineInfo): int =
      x.name.cmp y.name
  if formatKind == fJson:
    gen.genJson
  else:
    gen.genCtags

when isMainModule:
  var tags = TagGen()
  tags.add "path", "name", "line", 84, {
    kind: "function",
    scope: "scope",
    scopeKind: "scopeKind",
    signature: "signature"
  }.newOrderedTable
  echo tags.genJson()
  echo tags.genCtags()
