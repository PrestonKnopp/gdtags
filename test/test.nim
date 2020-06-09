# TODO: refactor gdtags.nim to be testable
# TODO: write tests

import ../src/[treesitter, treesittergdscript, tsutil]

let language = tree_sitter_gdscript()
let parser = ts_parser_new()

if not ts_parser_set_language(parser, language):
  echo "Fail"
