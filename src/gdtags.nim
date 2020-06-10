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
    --exclude-exception=<pattern>
        Add pattern to a list of patterns to find exceptions in --exclude files
        and directories when --recurse is enabled.
        The pattern is tested after an --exclude pattern succeeded. It tests
        first the full path of a file then just the file name.
        This option can be specified multiple times.
    --output-format=ctags|json                                  [default: ctags]
        Specify the output format. json format can be used for programs such as
        vista.vim.
    --json                                                            [default:]
        Shorthand for --output-format=json.
        Note: vista.vim looks for "--output-format=json" in the command to
        determine parser.
    -u                                                                [default:]
        Equivalent to --sort=no
    --sort=yes|no                                                 [default: yes]
        Sort tag file by tag name. This is required for programs to perform a
        binary search on the tags file.
    --omit-class-name                                                 [default:]
        Omit generating a tag for class name. You should specify this for
        programs like vista or tagbar to better display symbol hierarchy.
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
    of "output-format":
      if opt.val == "json":
        opts.format = fJson
      elif opt.val == "ctags":
        opts.format = fCtags
      else:
        eecho "Unknown format: ", opt.val
        eecho "Valid formats are: ctags, json"
        quit QuitFailure
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

proc processFile(file: string) =
  let source = file.readFile
  let tree = parser.parseString(nil, source.cstring, source.len.uint32)
  if tree == nil:
    eecho "Treesitter and treesittergdscript have differing ABI versions, please rebuild."
    return

  let root = tree.rootNode

  proc joinNamespace(ns, nns: string): string {.inline.} =
    if ns == "": nns else: ns & "." & nns

  proc firstLineSourceText(node: Node): string =
      # Get the source text line between two newlines
      var
        startIdx = node.startByte.int
        endIdx = startIdx
      # The following +- 1's are to skip the actual '\n'
      startIdx = source.rfind('\n', 0, startIdx) + 1
      endIdx = source.find('\n', endIdx) - 1
      if endIdx < 0: endIdx = source.high

      source.substr(startIdx, endIdx).multiReplace(
        ("\\", "\\\\"),
        ("/", "\\/"),
        ("$", "\\$"),
        ("^", "\\^"),
      )

  proc escapeSignature(s: string): string =
    s.multiReplace(
      ("\n", " "),
      ("\t", ""),
      ("\\", ""),
    )

  proc processSource(rootNode: Node, namespace: string="") =
    for node, nodeType in rootNode.childrenWithNames(nodeTypeKeys):

      let tag = node.firstChildNamed("name").text(source)
      let pattern = node.firstLineSourceText()
      let fields = newOrderedTable[Field, string]()
      # kind field should always be added first
      fields.add kind, nodeTypeKindMap[nodeType]
      if namespace != "":
        fields.add scopeKind, "class"
        fields.add scope, namespace

      case nodeType:
      of "enum_definition":
        node.descendantsWithNames "enumerator", proc (enumNode: Node, nt: string) =
          let enumTag = enumNode.firstChildNamed("identifier").text(source)
          let pattern = enumNode.firstLineSourceText()
          let lineNum = enumNode.startPoint.row.int.succ
          let startByte = enumNode.startByte
          let fields = newOrderedTable[Field, string]()

          fields.add kind, nodeTypeKindMap["enumerator"]
          let enumNamespace = joinNamespace(namespace, tag)
          if enumNamespace != "":
            fields.add scopeKind, "enumDef"
            fields.add scope, enumNamespace
          if enumNode.namedChildCount > 1:
            fields.add signature, " = " & enumNode.namedChild(1).text(source).escapeSignature
          if tag != "":
            fields.add fEnum, tag

          tags.add file, enumTag, pattern, lineNum, startByte, fields

        # enumDefs can be anonymous so the tag will be empty.  The other tag
        # kinds shouldn't be whitespace so only check it here.
        if tag.isEmptyOrWhitespace:
          continue

      of "signal_statement":
        let identListNode = node.firstChildNamed("identifier_list")
        if not identListNode.isNil:
          fields.add signature, escapeSignature("(" & identListNode.text(source) & ")")

      of "function_definition":
        let parametersNode = node.firstChildNamed("parameters")
        let returnTypeNode = node.firstChildNamed("return_type")
        var sig = ""
        if parametersNode.namedChildCount > 0:
          sig.add parametersNode.text(source)
        if not returnTypeNode.isNil:
          sig.add " " & returnTypeNode.text(source)
        if sig != "":
          fields.add signature, sig.escapeSignature

      of "class_definition":
        let body = node.firstChildNamed("body")
        processSource body, joinNamespace(namespace, tag)

      tags.add file, tag, pattern, node.startPoint.row.int.succ, node.startByte, fields

  if not opts.omitClassName:
    let classNameStmt = root.firstChildNamed("class_name_statement")
    if not classNameStmt.isNil:
      let stmtText = classNameStmt.firstLineSourceText()
      let className = classNameStmt.firstChildNamed("name").text(source)
      let lineNum = classNameStmt.startPoint.row.int.succ
      tags.add file, className, stmtText, lineNum, classNameStmt.startByte, {kind: "class"}.newOrderedTable

  processSource root

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

      processFile file

else:
  for inFile in opts.inFiles:
    processFile inFile

let output = tags.gen(opts.format, opts.sorted)
if opts.outFile.isEmptyOrWhitespace or opts.outFile == "-":
  stdout.write output
else:
  writeFile opts.outFile, output

parser.delete()
