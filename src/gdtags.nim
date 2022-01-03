import strutils, tables, sequtils
import "."/[debugutil, treesitter, treesittergdscript, tsutil, taggen]

const
  NimblePkgVersion {.strdefine.} = "Unknown"
    # Allow nimble to define gdtags' pkg version.
  help = staticRead "../help.txt"


const
  nodeNameFuncDef = "function_definition"
  nodeNameClassDef = "class_definition"
  nodeNameEnumDef = "enum_definition"
  nodeNameEnum = "enumerator"
  nodeNameSigStmt = "signal_statement"

  nodeNameToCtagKindMap = {
    "variable_statement": "variable",
    "export_variable_statement": "variable",
    "onready_variable_statement": "variable",
    "const_statement": "constant",
    nodeNameFuncDef: "function",
    nodeNameClassDef: "class",
    nodeNameEnumDef: "enumDef",
    nodeNameEnum: "enum",
    nodeNameSigStmt: "signal"
  }.toTable

  nodeNames = toSeq(nodeNameToCtagKindMap.keys)


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


proc processNode*(tags: TagGen, rootNode: Node; file, source: string; namespace: string="") =
  for node, nodeName in rootNode.childrenWithNames(nodeNames):

    let tagInfo = TagLineInfo(
        path: file,
        name: node.firstChildNamed("name").text(source),
        pattern: firstTextLine(source, node),
        lineNum: node.startPoint.row.int.succ,
        byteOffset: node.startByte,
        fields: newOrderedTable[Field, string](),
      )

    # kind field should always be added first
    tagInfo.fields[kind] = nodeNameToCtagKindMap[nodeName]

    if namespace != "":
      tagInfo.fields[scopeKind] = "class"
      tagInfo.fields[scope] = namespace

    case nodeName:
    of nodeNameEnumDef:
      for enumNode, _ in descendantsWithNames(node, nodeNameEnum):
        let enumTagInfo = TagLineInfo(
            path: file,
            name: enumNode.firstChildNamed("identifier").text(source),
            pattern: firstTextLine(source, enumNode),
            lineNum: enumNode.startPoint.row.int.succ,
            byteOffset: enumNode.startByte,
            fields: newOrderedTable[Field, string](),
          )

        # kind field should always be added first
        enumTagInfo.fields[kind] = nodeNameToCtagKindMap[nodeNameEnum]

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

    of nodeNameSigStmt:
      let identListNode = node.firstChildNamed("identifier_list")
      if not identListNode.isNil:
        tagInfo.fields[signature] = "(" & identListNode.text(source) & ")"

    of nodeNameFuncDef:
      let parametersNode = node.firstChildNamed("parameters")
      let returnTypeNode = node.firstChildNamed("return_type")
      var sig = ""
      if parametersNode.namedChildCount > 0:
        sig.add parametersNode.text(source)
      if not returnTypeNode.isNil:
        sig.add " " & returnTypeNode.text(source)
      if sig != "":
        tagInfo.fields[signature] = sig

    of nodeNameClassDef:
      let body = node.firstChildNamed("body")
      processNode tags, body, file, source, joinNamespace(namespace, tagInfo.name)

    tags.add tagInfo


proc processFile*(tags: TagGen, parser: ptr Parser, file: string, omitClassName: bool) =
  let source = file.readFile
  let tree = parser.parseString(nil, source.cstring, source.len.uint32)
  if tree == nil:
    eecho "Treesitter and treesittergdscript have differing ABI versions, please rebuild."
    return

  let root = tree.rootNode

  if not omitClassName:
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


when isMainModule:
  import os, parseopt
  import nre except toSeq, toTable

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
        stdout.write help
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

  let
    gdscript = newGdscript()
    parser = newParser()
    tags = TagGen()

  if not parser.setLanguage(gdscript):
    eecho "Failed to set parser language to gdscript."
    quit QuitFailure

  if opts.recurse:

    let
      excludeRegs: seq[Regex] = opts.exclude.map(re)
      excludeExRegs: seq[Regex] = opts.excludeEx.map(re)

    var i = 0
    while succ(i) < len(opts.inFiles):
      # Only loop over files if there are more than one inFiles.
      # At the same time: continue looping while there is 1 or more than i
      # inFiles remaining.
      # ---
      # Reduce repeating dirs by removing dirs that will
      # be traversed with an ancestor dir.
      let iFile = opts.inFiles[i]
      var didDel_iFile = false

      var j = succ(i)
      while j < len(opts.inFiles):
        let jFile = opts.inFiles[j]

        if isRelativeTo(path = jFile, base = iFile) or jFile == iFile:
          # iFile includes or equals jFile. We don't need jFile.
          del(opts.inFiles, j)
          continue # to use current j index.

        elif isRelativeTo(path = iFile, base = jFile):
          # jFile includes iFile. We don't need iFile.
          del(opts.inFiles, i)
          didDel_iFile = true
          break # because iFile is invalid.

        inc(j)

      if not didDel_iFile:
        inc(i)

    if opts.inFiles.len == 0:
      opts.inFiles.add "."

    decho opts.inFiles


    type DirStack = seq[tuple[dir: string, depth: int]]
    const maxDepthUnlimitedValue = 0

    for inFile in opts.inFiles:
      var stack: DirStack = @{inFile: 0}

      while stack.len > 0:
        let data = stack.pop()

        for kind, path in walkDir(data.dir):
          case kind
          of pcDir, pcLinkToDir:
            if opts.maxDepth == maxDepthUnlimitedValue or succ(data.depth) < opts.maxDepth:
              stack.add( (path, succ(data.depth)) )

          of pcFile, pcLinkToFile:
            if path.endsWith(".gd"):
              var shouldInclude = true

              for excludeReg in excludeRegs:
                if path.contains(excludeReg):
                  shouldInclude = false
                  break

              if shouldInclude:
                for excludeExReg in excludeExRegs:
                  if path.contains(excludeExReg):
                    shouldInclude = true
                    break

              if shouldInclude:
                processFile(tags, parser, path, opts.omitClassName)

  else:
    for inFile in opts.inFiles:
      processFile tags, parser, inFile, opts.omitClassName

  let output = tags.gen(opts.format, opts.sorted)
  if opts.outFile.isEmptyOrWhitespace or opts.outFile == "-":
    stdout.write output
  else:
    writeFile opts.outFile, output

  parser.delete()

