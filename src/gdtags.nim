const NimblePkgVersion {.strdefine.} = "Unknown"
# Allow nimble to define gdtags' pkg version.

const help = """
USAGE
    gdtags [options] [<file>...]
    gdtags [options] (-R | --recurse) [<directory>...]

OPTIONS
    -o=<file>,-f=<file>,--output=<file>                             [default: -]
        Specify the file to output generated tags. Defaults to stdout.
    -R,--recurse                                                      [default:]
        Recursively generate tags for every gdscript file in directory.
    --maxdepth=N                                                    [default: 0]
        Limit the depth of directory recursion enabled with the --recurse (-R)
        option.
        NOTE: This is not implemented yet.
    --exclude=<pattern>                                               [default:]
        Add pattern to a list of patterns to exclude files and directories when
        --recurse is enabled.
        The pattern is tested on first the full path of a file then just the
        file name.
        This option can be specified multiple times.
    --exclude-exception=<pattern>                                     [default:]
        Add pattern to a list of patterns to find exceptions in --exclude files
        and directories when --recurse is enabled.
        The pattern is tested after an --exclude pattern succeeded. It tests
        first the full path of a file then just the file name.
        This option can be specified multiple times.
    --output-format=ctags|etags|json                            [default: ctags]
        Specify the output format.
        Use etags format to generate tags for emacs.
        json format can be used for programs such as vista.vim.
    --json                                                            [default:]
        Shorthand for --output-format=json.
        Note: vista.vim looks for "--output-format=json" in the command to
        determine parser.
    --emacs                                                           [default:]
        Shorthand for --output-format=etags.
    -u                                                                [default:]
        Equivalent to --sort=no
    --sort=yes|no                                                 [default: yes]
        Sort tag file by tag name. This is required for programs to perform a
        binary search on the tags file.
    --omit-class-name                                                 [default:]
        Omit generating a tag for class name. You should specify this for
        programs like vista or tagbar to better display symbol hierarchy.
    --version                                                         [default:]
        Print version and then exit.
    -h,--help,-?
        Print this help and then exit."""

import os, parseopt, strutils, tables, sequtils
import nre except toSeq, toTable
import "."/[debugutil, treesitter, treesittergdscript, tsutil, taggen]

type
  Options = object
    inFiles: seq[string]
    outFile: string
    recurse: bool
    maxDepth: int
    exclude: seq[string]
    excludeEx: seq[string]
    format: FormatKind
    sorted: bool
    omitClassName: bool
    unknownOpts: seq[string]

proc initOptions(): Options =
  result.inFiles = newSeq[string]()
  result.outFile = "-"
  result.recurse = false
  result.maxDepth = 0
  result.exclude = newSeq[string]()
  result.excludeEx = newSeq[string]()
  result.format = fCtags
  result.sorted = true
  result.omitClassName = false
  result.unknownOpts = newSeq[string]()

var opts = initOptions()

for opt in getopt():
  decho opt
  case opt.kind:
  of cmdLongOption, cmdShortOption:
    case opt.key:
    of "o", "f", "output": opts.outFile = opt.val
    of "R", "recurse": opts.recurse = true
    of "maxdepth": opts.maxDepth = opt.val.parseInt
    of "exclude": opts.exclude.add opt.val
    of "exclude-exception": opts.excludeEx.add opt.val
    of "u": opts.sorted = false
    of "sort": opts.sorted = opt.val.parseBool
    of "omit-class-name": opts.omitClassName = true
    of "json": opts.format = fJson
    of "emacs": opts.format = fEtags
    of "output-format":
      if opt.val == "json":
        opts.format = fJson
      elif opt.val == "ctags":
        opts.format = fCtags
      elif opt.val == "etags":
        opts.format = fEtags
      else:
        eecho "Unknown format: ", opt.val
        eecho "Valid formats are: ctags, json"
        quit QuitFailure
    of "version":
        echo 'v', NimblePkgVersion
        quit QuitSuccess
    of "?", "h", "help":
      echo help
      quit QuitSuccess
    else:
      let key = (if opt.kind == cmdShortOption: "-" else: "--") & opt.key
      opts.unknownOpts.add key & (if opt.val.len == 0: "" else: "=" & opt.val)
  of cmdArgument:
    opts.inFiles.add opt.key
  of cmdEnd:
    discard

decho $opts

block:
  var checksPassed = true

  if opts.unknownOpts.len > 0:
    eecho "Unknown options: ", opts.unknownOpts.join(" ")
    checksPassed = false

  if opts.outFile != "-":
    if opts.outFile.dirExists:
      eecho "--output file cannot be a directory"
      checksPassed = false

  for file in opts.inFiles:
    let exists = file.fileExists
    if opts.recurse:
      if exists:
        eecho "Cannot --recurse a file: ", file
        checksPassed = false
      elif not file.dirExists:
        eecho "Cannot --recurse non existant directory: ", file
        checksPassed = false
    elif not exists:
      eecho "GDScript file does not exist: ", file
      checksPassed = false

  if not checksPassed:
    quit QuitFailure

const
  nodeTypeKindMap = {
    "variable_statement": "variable",
    "export_variable_statement": "variable",
    "onready_variable_statement": "variable",
    "const_statement": "constant",
    "function_definition": "function",
    "class_definition": "class",
    "enum_definition": "enumDef",
    "enumerator": "enum",
    "signal_statement": "signal"
  }.toTable
  nodeTypeKeys = toSeq(nodeTypeKindMap.keys)

let
  gdscript = newGdscript()
  parser = newParser()
  tags = TagGen()

if not parser.setLanguage(gdscript):
  eecho "Failed to set parser language to gdscript."
  quit QuitFailure


func joinNamespace(ns, newNs: string): string {.inline.} =
  if ns == "": newNs else: ns & "." & newNs


func firstTextLine(source: string, node: Node): string =
    # Get the first line of source text that lies between two newlines.
    var
      startIdx = node.startByte.int
      endIdx = startIdx
    # The following +- 1's are to skip the actual '\n'
    startIdx = source.rfind('\n', 0, startIdx) + 1
    endIdx = source.find('\n', endIdx) - 1
    if endIdx < 0: endIdx = source.high

    source.substr(startIdx, endIdx)


proc processNode(tags: TagGen, rootNode: Node; file, source: string; namespace: string="") =
  for node, nodeType in rootNode.childrenWithNames(nodeTypeKeys):

    let tagInfo = TagLineInfo(
        path: file,
        name: node.firstChildNamed("name").text(source),
        pattern: firstTextLine(source, node),
        lineNum: node.startPoint.row.int.succ,
        byteOffset: node.startByte,
        fields: newOrderedTable[Field, string](),
      )

    # kind field should always be added first
    tagInfo.fields[kind] = nodeTypeKindMap[nodeType]

    if namespace != "":
      tagInfo.fields[scopeKind] = "class"
      tagInfo.fields[scope] = namespace

    case nodeType:
    of "enum_definition":
      node.descendantsWithNames "enumerator", proc (enumNode: Node, nt: string) =
        let enumTagInfo = TagLineInfo(
            path: file,
            name: enumNode.firstChildNamed("identifier").text(source),
            pattern: firstTextLine(source, enumNode),
            lineNum: enumNode.startPoint.row.int.succ,
            byteOffset: enumNode.startByte,
            fields: newOrderedTable[Field, string](),
          )

        # kind field should always be added first
        enumTagInfo.fields[kind] = nodeTypeKindMap["enumerator"]

        let enumNamespace = joinNamespace(namespace, tagInfo.name)
        if enumNamespace != "":
          enumTagInfo.fields[scopeKind] = "enumDef"
          enumTagInfo.fields[scope] = enumNamespace

        if enumNode.namedChildCount > 1:
          enumTagInfo.fields[signature] = " = " & enumNode.namedChild(1).text(source)

        if tagInfo.name != "":
          enumTagInfo.fields[fEnum] = tagInfo.name

        tags.add enumTagInfo

      # enumDefs can be anonymous so the name will be empty.  The other tag
      # kinds shouldn't be whitespace so only check it here.
      if tagInfo.name.isEmptyOrWhitespace:
        continue

    of "signal_statement":
      let identListNode = node.firstChildNamed("identifier_list")
      if not identListNode.isNil:
        tagInfo.fields[signature] = "(" & identListNode.text(source) & ")"

    of "function_definition":
      let parametersNode = node.firstChildNamed("parameters")
      let returnTypeNode = node.firstChildNamed("return_type")
      var sig = ""
      if parametersNode.namedChildCount > 0:
        sig.add parametersNode.text(source)
      if not returnTypeNode.isNil:
        sig.add " " & returnTypeNode.text(source)
      if sig != "":
        tagInfo.fields[signature] = sig

    of "class_definition":
      let body = node.firstChildNamed("body")
      processNode tags, body, file, source, joinNamespace(namespace, tagInfo.name)

    tags.add tagInfo


proc processFile(tags: TagGen, parser: ptr Parser, file: string) =
  let source = file.readFile
  let tree = parser.parseString(nil, source.cstring, source.len.uint32)
  if tree == nil:
    eecho "Treesitter and treesittergdscript have differing ABI versions, please rebuild."
    return

  let root = tree.rootNode

  if not opts.omitClassName:
    let classNameStmt = root.firstChildNamed("class_name_statement")
    if not classNameStmt.isNil:
      tags.add TagLineInfo(
          path: file,
          name: classNameStmt.firstChildNamed("name").text(source),
          pattern: firstTextLine(source, classNameStmt),
          lineNum: classNameStmt.startPoint.row.int.succ,
          byteOffset: classNameStmt.startByte,
          fields: newOrderedTable({kind: "class"})
        )

  processNode tags, root, file, source


if opts.recurse:

  var excludeRegs: seq[Regex] = @[]
  var excludeExRegs: seq[Regex] = @[]

  for exclude in opts.exclude:
    excludeRegs.add exclude.re
  for excludeEx in opts.excludeEx:
    excludeExRegs.add excludeEx.re

  if opts.inFiles.len == 0:
    opts.inFiles.add "."

  for inFile in opts.inFiles:
    for file in walkDirRec(inFile):
      if not file.endsWith(".gd"):
        continue

      var shouldExclude = false
      for excludeReg in excludeRegs:
        if file.contains(excludeReg):
          shouldExclude = true
          break

      if shouldExclude:
        for excludeExReg in excludeExRegs:
          if file.contains(excludeExReg):
            shouldExclude = false
            break

      if shouldExclude:
        continue

      processFile tags, parser, file

else:
  for inFile in opts.inFiles:
    processFile tags, parser, inFile

let output = tags.gen(opts.format, opts.sorted)
if opts.outFile.isEmptyOrWhitespace or opts.outFile == "-":
  stdout.write output
else:
  writeFile opts.outFile, output

parser.delete()
