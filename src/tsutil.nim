import "."/[treesitter]

iterator childrenWithNames*(node: Node, names: varargs[string]): ( Node, string ) =
  if not node.isNil:
    var n = node.namedChild(0)
    while not n.isNil:
      # node types are the same as names for named nodes
      let name = $n.name
      if name in names:
        yield (n, name)
      n = n.nextNamedSibling

## Recursively descend tree via cursor calling `callback`
##
## This cursor is copied which retains cursor state from call site when this
## proc returns.
proc descendantsWithNames*(node: Node, names: varargs[string], callback: proc (node: Node, nodeType: string)) =
  if node.isNil:
    return

  var cursor = node.newTreeCursor
  defer: cursor.delete()

  if not cursor.gotoFirstChild:
    return

  while true:

    let node = cursor.currentNode
    let name = $node.name

    if name in names:
      callback node, name
    else:
      node.descendantsWithNames names, callback

    if not cursor.gotoNextSibling:
      break

proc firstChildNamed*(node: Node, name: string): Node =
  for n in node.childrenWithNames(name):
    return n[0]

proc firstNodeForPath*(node: Node, path: varargs[string]): Node =
  result = node
  for p in path:
    if result.isNil: break
    result = result.firstChildNamed(p)

proc text*(node: Node, source: string): string =
  if node.isNil:
    return ""

  source.substr(node.startbyte.int, node.endByte.int.pred)

when isMainModule:
  import "."/treesittergdscript
  var source = """
  enum Hello {
    ONE
  }
  var hello: String
  var goodbye: World
  func okay():
    pass
  """

  let p = newParser()
  discard p.setLanguage newGdscript()

  let
    t = p.parseString(nil, source.cstring, source.len.uint32)
    r = t.rootNode

  echo r.hasError
  echo r.toLisp
  var v = r.firstChildNamed("variable_statement")
  echo v, v.hasError
  echo r.firstNodeForPath("variable_statement", "name")
  echo r.firstNodeForPath("variable_statement", "name").text(source)

  proc ch(c: var TreeCursor) =
    c.currentNode.name.echo
    c.currentNode.namedChildCount.echo

  var tc = r.newTreeCursor
  tc.ch
  tc.gotoFirstChild.echo
  tc.ch
  var tc2 = tc
  tc2.ch
  tc.gotoFirstChild.echo
  tc.ch
  tc2.ch
