## Utilities for working with tree sitter syntax trees.
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

iterator descendantsWithNames*(node: Node, names: varargs[string]): ( Node, string ) =
  var
    cursor = newTreeCursor(node)
    stack = @[node]

  defer: delete(cursor)

  while stack.len > 0:
    cursor.reset(stack.pop())

    if cursor.gotoFirstChild():
      while true:
        if $cursor.currentNode.name in names:
          yield (cursor.currentNode, $cursor.currentNode.name)
        elif cursor.currentNode.namedChildCount > 0:
          stack.add(cursor.currentNode)

        if not cursor.gotoNextSibling():
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
    var inner_func_var = 1
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
    echo c.currentNode.name, ":", c.currentNode.text(source), " namedChildcount: ", c.currentNode.namedChildCount

  var vs = r.firstNodeForPath("variable_statement")

  var tc = r.newTreeCursor
  tc.ch
  tc.gotoFirstChild.echo
  tc.ch
  var tc2 = tc
  tc2.ch
  tc.gotoFirstChild.echo
  tc.ch
  tc2.ch

  echo "---"
  # tc.reset(vs) # reset uses the given node as a new *root* node.
  tc = newTreeCursor vs
  tc.ch
  echo "Next Sib? ", tc.gotoNextSibling() # false
  echo "Parent? ", tc.gotoParent() # false
  echo "Child? ", tc.gotoFirstChild() # true
  echo "Then Parent? ", tc.gotoParent()
  tc.ch

  for node, name in descendantsWithNames(r, "variable_statement", "enumerator"):
    echo name, "::", node.text(source)
