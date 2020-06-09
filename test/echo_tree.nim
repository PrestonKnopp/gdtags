import os
import ../src/[treesitter, treesittergdscript]

let p = newParser()
let l = newGdscript()
let a = commandLineParams()

if not p.setLanguage(l):
  stderr.writeLine "Failed to set language"
  quit QuitFailure

proc repl() =
  var content = ""
  stdout.write(">> ")
  for line in stdin.lines:
    if line == "":
      let t = p.parseString(nil, content.cstring, content.len.uint32)
      if not t.isNil:
        t.rootNode.toLisp.echo
      content = ""
    else:
      content.add line & "\n"
    stdout.write(">> ")


proc readInFile() =
  for arg in a:
    let contents = arg.readFile
    let t = p.parseString(nil, contents.cstring, contents.len.uint32)
    if not t.isNil:
      t.rootNode.toLisp.echo

if a.len == 0:
  repl()
else:
  readInFile()
