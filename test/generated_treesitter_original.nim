{.hint[ConvFromXtoItselfNotNeeded]: off.}

import nimterop/types


defineEnum(TSInputEncoding)
defineEnum(TSSymbolType)
defineEnum(TSLogType)
defineEnum(TSQueryPredicateStepType)
defineEnum(TSQueryError)

const
  headerapi {.used.} = ".cache/nim/nimterop/treesitter/lib/include/tree_sitter/api.h"
  TREE_SITTER_LANGUAGE_VERSION* = 11
  TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION* = 9
  TSInputEncodingUTF8* = 0.TSInputEncoding
  TSInputEncodingUTF16* = 1.TSInputEncoding
  TSSymbolTypeRegular* = 0.TSSymbolType
  TSSymbolTypeAnonymous* = 1.TSSymbolType
  TSSymbolTypeAuxiliary* = 2.TSSymbolType
  TSLogTypeParse* = 0.TSLogType
  TSLogTypeLex* = 1.TSLogType
  TSQueryPredicateStepTypeDone* = 0.TSQueryPredicateStepType
  TSQueryPredicateStepTypeCapture* = 1.TSQueryPredicateStepType
  TSQueryPredicateStepTypeString* = 2.TSQueryPredicateStepType
  TSQueryErrorNone* = (0).TSQueryError
  TSQueryErrorSyntax* = 1.TSQueryError
  TSQueryErrorNodeType* = 2.TSQueryError
  TSQueryErrorField* = 3.TSQueryError
  TSQueryErrorCapture* = 4.TSQueryError

{.pragma: impapi, importc, header: headerapi.}
{.pragma: impapiC, impapi, cdecl.}

type
  TSSymbol* {.impapi.} = uint16
  TSFieldId* {.impapi.} = uint16
  TSLanguage* {.impapi, incompleteStruct.} = object
  TSParser* {.impapi, incompleteStruct.} = object
  TSTree* {.impapi, incompleteStruct.} = object
  TSQuery* {.impapi, incompleteStruct.} = object
  TSQueryCursor* {.impapi, incompleteStruct.} = object
  TSPoint* {.impapi, bycopy.} = object
    row*: uint32
    column*: uint32
  TSRange* {.impapi, bycopy.} = object
    start_point*: TSPoint
    end_point*: TSPoint
    start_byte*: uint32
    end_byte*: uint32
  TSInput* {.impapi, bycopy.} = object
    payload*: pointer
    read*: proc(payload: pointer, byte_index: uint32, position: TSPoint, bytes_read: ptr uint32): cstring {.cdecl.}
    encoding*: TSInputEncoding
  TSLogger* {.impapi, bycopy.} = object
    payload*: pointer
    log*: proc(payload: pointer, a1: TSLogType, a2: cstring) {.cdecl.}
  TSInputEdit* {.impapi, bycopy.} = object
    start_byte*: uint32
    old_end_byte*: uint32
    new_end_byte*: uint32
    start_point*: TSPoint
    old_end_point*: TSPoint
    new_end_point*: TSPoint
  TSNode* {.impapi, bycopy.} = object
    context*: array[4, uint32]
    id*: pointer
    tree*: ptr TSTree
  TSTreeCursor* {.impapi, bycopy.} = object
    tree*: pointer
    id*: pointer
    context*: array[2, uint32]
  TSQueryCapture* {.impapi, bycopy.} = object
    node*: TSNode
    index*: uint32
  TSQueryMatch* {.impapi, bycopy.} = object
    id*: uint32
    pattern_index*: uint16
    capture_count*: uint16
    captures*: ptr TSQueryCapture
  TSQueryPredicateStep* {.impapi, bycopy.} = object
    `type`*: TSQueryPredicateStepType
    value_id*: uint32


proc ts_parser_new*(): ptr TSParser {.impapiC.}
proc ts_parser_delete*(parser: ptr TSParser) {.impapiC.}
proc ts_parser_set_language*(self: ptr TSParser, language: ptr TSLanguage): bool {.impapiC.}
proc ts_parser_language*(self: ptr TSParser): ptr TSLanguage {.impapiC.}
proc ts_parser_set_included_ranges*(self: ptr TSParser, ranges: ptr TSRange, length: uint32): bool {.impapiC.}
proc ts_parser_included_ranges*(self: ptr TSParser, length: ptr uint32): ptr TSRange {.impapiC.}
proc ts_parser_parse*(self: ptr TSParser, old_tree: ptr TSTree, input: TSInput): ptr TSTree {.impapiC.}
proc ts_parser_parse_string*(self: ptr TSParser, old_tree: ptr TSTree, string: cstring, length: uint32): ptr TSTree {.impapiC.}
proc ts_parser_parse_string_encoding*(self: ptr TSParser, old_tree: ptr TSTree, string: cstring, length: uint32, encoding: TSInputEncoding): ptr TSTree {.impapiC.}
proc ts_parser_reset*(self: ptr TSParser) {.impapiC.}
proc ts_parser_set_timeout_micros*(self: ptr TSParser, timeout: uint64) {.impapiC.}
proc ts_parser_timeout_micros*(self: ptr TSParser): uint64 {.impapiC.}
proc ts_parser_set_cancellation_flag*(self: ptr TSParser, flag: ptr uint) {.impapiC.}
proc ts_parser_cancellation_flag*(self: ptr TSParser): ptr uint {.impapiC.}
proc ts_parser_set_logger*(self: ptr TSParser, logger: TSLogger) {.impapiC.}
proc ts_parser_logger*(self: ptr TSParser): TSLogger {.impapiC.}
proc ts_parser_print_dot_graphs*(self: ptr TSParser, file: cint) {.impapiC.}
proc ts_tree_copy*(self: ptr TSTree): ptr TSTree {.impapiC.}
proc ts_tree_delete*(self: ptr TSTree) {.impapiC.}
proc ts_tree_root_node*(self: ptr TSTree): TSNode {.impapiC.}
proc ts_tree_language*(a1: ptr TSTree): ptr TSLanguage {.impapiC.}
proc ts_tree_edit*(self: ptr TSTree, edit: ptr TSInputEdit) {.impapiC.}
proc ts_tree_get_changed_ranges*(old_tree: ptr TSTree, new_tree: ptr TSTree, length: ptr uint32): ptr TSRange {.impapiC.}
proc ts_tree_print_dot_graph*(a1: ptr TSTree, a2: ptr FILE) {.impapiC.}
proc ts_node_type*(a1: TSNode): cstring {.impapiC.}
proc ts_node_symbol*(a1: TSNode): TSSymbol {.impapiC.}
proc ts_node_start_byte*(a1: TSNode): uint32 {.impapiC.}
proc ts_node_start_point*(a1: TSNode): TSPoint {.impapiC.}
proc ts_node_end_byte*(a1: TSNode): uint32 {.impapiC.}
proc ts_node_end_point*(a1: TSNode): TSPoint {.impapiC.}
proc ts_node_string*(a1: TSNode): cstring {.impapiC.}
proc ts_node_is_null*(a1: TSNode): bool {.impapiC.}
proc ts_node_is_named*(a1: TSNode): bool {.impapiC.}
proc ts_node_is_missing*(a1: TSNode): bool {.impapiC.}
proc ts_node_is_extra*(a1: TSNode): bool {.impapiC.}
proc ts_node_has_changes*(a1: TSNode): bool {.impapiC.}
proc ts_node_has_error*(a1: TSNode): bool {.impapiC.}
proc ts_node_parent*(a1: TSNode): TSNode {.impapiC.}
proc ts_node_child*(a1: TSNode, a2: uint32): TSNode {.impapiC.}
proc ts_node_child_count*(a1: TSNode): uint32 {.impapiC.}
proc ts_node_named_child*(a1: TSNode, a2: uint32): TSNode {.impapiC.}
proc ts_node_named_child_count*(a1: TSNode): uint32 {.impapiC.}
proc ts_node_child_by_field_name*(self: TSNode, field_name: cstring, field_name_length: uint32): TSNode {.impapiC.}
proc ts_node_child_by_field_id*(a1: TSNode, a2: TSFieldId): TSNode {.impapiC.}
proc ts_node_next_sibling*(a1: TSNode): TSNode {.impapiC.}
proc ts_node_prev_sibling*(a1: TSNode): TSNode {.impapiC.}
proc ts_node_next_named_sibling*(a1: TSNode): TSNode {.impapiC.}
proc ts_node_prev_named_sibling*(a1: TSNode): TSNode {.impapiC.}
proc ts_node_first_child_for_byte*(a1: TSNode, a2: uint32): TSNode {.impapiC.}
proc ts_node_first_named_child_for_byte*(a1: TSNode, a2: uint32): TSNode {.impapiC.}
proc ts_node_descendant_for_byte_range*(a1: TSNode, a2: uint32, a3: uint32): TSNode {.impapiC.}
proc ts_node_descendant_for_point_range*(a1: TSNode, a2: TSPoint, a3: TSPoint): TSNode {.impapiC.}
proc ts_node_named_descendant_for_byte_range*(a1: TSNode, a2: uint32, a3: uint32): TSNode {.impapiC.}
proc ts_node_named_descendant_for_point_range*(a1: TSNode, a2: TSPoint, a3: TSPoint): TSNode {.impapiC.}
proc ts_node_edit*(a1: ptr TSNode, a2: ptr TSInputEdit) {.impapiC.}
proc ts_node_eq*(a1: TSNode, a2: TSNode): bool {.impapiC.}
proc ts_tree_cursor_new*(a1: TSNode): TSTreeCursor {.impapiC.}
proc ts_tree_cursor_delete*(a1: ptr TSTreeCursor) {.impapiC.}
proc ts_tree_cursor_reset*(a1: ptr TSTreeCursor, a2: TSNode) {.impapiC.}
proc ts_tree_cursor_current_node*(a1: ptr TSTreeCursor): TSNode {.impapiC.}
proc ts_tree_cursor_current_field_name*(a1: ptr TSTreeCursor): cstring {.impapiC.}
proc ts_tree_cursor_current_field_id*(a1: ptr TSTreeCursor): TSFieldId {.impapiC.}
proc ts_tree_cursor_goto_parent*(a1: ptr TSTreeCursor): bool {.impapiC.}
proc ts_tree_cursor_goto_next_sibling*(a1: ptr TSTreeCursor): bool {.impapiC.}
proc ts_tree_cursor_goto_first_child*(a1: ptr TSTreeCursor): bool {.impapiC.}
proc ts_tree_cursor_goto_first_child_for_byte*(a1: ptr TSTreeCursor, a2: uint32): int64 {.impapiC.}
proc ts_tree_cursor_copy*(a1: ptr TSTreeCursor): TSTreeCursor {.impapiC.}
proc ts_query_new*(language: ptr TSLanguage, source: cstring, source_len: uint32, error_offset: ptr uint32, error_type: ptr TSQueryError): ptr TSQuery {.impapiC.}
proc ts_query_delete*(a1: ptr TSQuery) {.impapiC.}
proc ts_query_pattern_count*(a1: ptr TSQuery): uint32 {.impapiC.}
proc ts_query_capture_count*(a1: ptr TSQuery): uint32 {.impapiC.}
proc ts_query_string_count*(a1: ptr TSQuery): uint32 {.impapiC.}
proc ts_query_start_byte_for_pattern*(a1: ptr TSQuery, a2: uint32): uint32 {.impapiC.}
proc ts_query_predicates_for_pattern*(self: ptr TSQuery, pattern_index: uint32, length: ptr uint32): ptr TSQueryPredicateStep {.impapiC.}
proc ts_query_capture_name_for_id*(a1: ptr TSQuery, id: uint32, length: ptr uint32): cstring {.impapiC.}
proc ts_query_string_value_for_id*(a1: ptr TSQuery, id: uint32, length: ptr uint32): cstring {.impapiC.}
proc ts_query_disable_capture*(a1: ptr TSQuery, a2: cstring, a3: uint32) {.impapiC.}
proc ts_query_disable_pattern*(a1: ptr TSQuery, a2: uint32) {.impapiC.}
proc ts_query_cursor_new*(): ptr TSQueryCursor {.impapiC.}
proc ts_query_cursor_delete*(a1: ptr TSQueryCursor) {.impapiC.}
proc ts_query_cursor_exec*(a1: ptr TSQueryCursor, a2: ptr TSQuery, a3: TSNode) {.impapiC.}
proc ts_query_cursor_set_byte_range*(a1: ptr TSQueryCursor, a2: uint32, a3: uint32) {.impapiC.}
proc ts_query_cursor_set_point_range*(a1: ptr TSQueryCursor, a2: TSPoint, a3: TSPoint) {.impapiC.}
proc ts_query_cursor_next_match*(a1: ptr TSQueryCursor, match: ptr TSQueryMatch): bool {.impapiC.}
proc ts_query_cursor_remove_match*(a1: ptr TSQueryCursor, id: uint32) {.impapiC.}
proc ts_query_cursor_next_capture*(a1: ptr TSQueryCursor, match: ptr TSQueryMatch, capture_index: ptr uint32): bool {.impapiC.}
proc ts_language_symbol_count*(a1: ptr TSLanguage): uint32 {.impapiC.}
proc ts_language_symbol_name*(a1: ptr TSLanguage, a2: TSSymbol): cstring {.impapiC.}
proc ts_language_symbol_for_name*(self: ptr TSLanguage, string: cstring, length: uint32, is_named: bool): TSSymbol {.impapiC.}
proc ts_language_field_count*(a1: ptr TSLanguage): uint32 {.impapiC.}
proc ts_language_field_name_for_id*(a1: ptr TSLanguage, a2: TSFieldId): cstring {.impapiC.}
proc ts_language_field_id_for_name*(a1: ptr TSLanguage, a2: cstring, a3: uint32): TSFieldId {.impapiC.}
proc ts_language_symbol_type*(a1: ptr TSLanguage, a2: TSSymbol): TSSymbolType {.impapiC.}
proc ts_language_version*(a1: ptr TSLanguage): uint32 {.impapiC.}

