extends Node
class_name ScriptD

export(String) var exported_var: String = "Export"

var hello: String = "Hello"

func my_func(param: int, other: String) -> void:
	pass

class InnerClass:
	var inner_var = "okay"

	func inner_func(a, b):
		var func_var: int = 0
		print(func_var)

