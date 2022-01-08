## Data structure for tag data.
##
## Can output tag data in ctags, etags, or json format.
import tables, strutils, strformat, algorithm, json

type
  FormatKind* = enum
    fJson, fCtags, fEtags

  Field* = enum
    kind, lineNum,
    scopeKind, scope,
    signature, fEnum

  TagLineInfo* = object
    path*: string
    name*: string
    pattern*: string
    lineNum*: int
    byteOffset*: uint32
    fields*: OrderedTableRef[Field, string]

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

proc add*(gen: TagGen, tagInfo: TagLineInfo): void =
  gen.lines.add tagInfo

proc escapePattern(s: string): string =
  s.multiReplace(
    ("\\", "\\\\"),
    ("/", "\\/"),
    ("$", "\\$"),
    ("^", "\\^"),
  )

proc escapeSignatureField(fields: OrderedTableRef) =
  if signature in fields:
    fields[signature] = fields[signature].multiReplace(
      ("\n", " "),
      ("\t", ""),
      ("\\", ""),
    )

proc genCtags(gen: TagGen): string =
  result = ""
  for line in gen.lines:
    let pattern = line.pattern.escapePattern
    line.fields.escapeSignatureField
    result.add &"{line.name}\t{line.path}\t/^{pattern}$/;\""
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

# See: https://en.wikipedia.org/wiki/Ctags#Etags
#
# Etags format:
#
# 1. The section header
# 
# \x0c
# {src_file},{size_of_tag_definition_data_in_bytes}
#
# 2. Tag definitions
#
# {tag_definition_text}\x7f{tagname}\x01{line_number},{byte_offset}
#
# Note: The size of tag definition data is the total number of bytes
# of all the tag definitions including new lines.
proc genEtags(gen: TagGen): string =
  var
    currentSectionPath: string
    tagDataDefinitions: string

  proc commitTagData(res: var string) =
    res.add "\x0c\n"
    res.add &"{currentSectionPath},{tagDataDefinitions.len}\n"
    res.add tagDataDefinitions

  for line in gen.lines:
    if currentSectionPath != line.path:
      if not currentSectionPath.isEmptyOrWhitespace:
        result.commitTagData()
      currentSectionPath = line.path
      tagDataDefinitions = ""

    tagDataDefinitions.add &"{line.pattern}\x7f{line.name}\x01{line.lineNum},{line.byteOffset}\n"

  if not currentSectionPath.isEmptyOrWhitespace:
    result.commitTagData()

proc genJson(gen: TagGen): string =
  for line in gen.lines:
    let pattern = line.pattern.escapePattern
    line.fields.escapeSignatureField
    var lineJson = %* {
      "_type": "tag",
      "name": line.name,
      "path": line.path,
      "pattern": "/^" & pattern & "$/",
      "line": line.lineNum,
    }
    for key, val in line.fields:
      if key == lineNum: continue
      lineJson[fieldNameMap[key]] = %* val
    result.add $lineJson & "\n"

proc gen*(gen: TagGen, formatKind: FormatKind, sorted: bool=true): string =
  # Sorting tags is ignored for emacs etags.
  if sorted and not (formatKind == fEtags):
    gen.lines.sort proc (x, y: TagLineInfo): int =
      x.name.cmp y.name
  if formatKind == fJson:
    gen.genJson()
  elif formatKind == fEtags:
    gen.genEtags()
  else:
    gen.genCtags()
