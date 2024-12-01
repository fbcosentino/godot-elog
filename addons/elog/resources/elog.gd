class_name Elog
extends Node

const FUNC_TYPE = {
	"(": "auto",
	"[": "fact",
	"{": "rule",
}

var FIRST_CAPITAL_CHAR := "A".unicode_at(0) # In practice a constant
var LAST_CAPITAL_CHAR := "Z".unicode_at(0) # In practice a constant

var last_error_message = ""
var objects := []
var facts := {
	# "fact name": [
	#      ["arg1", "arg2", ...],
	#      ["arg3", "arg4", ...],
	# ],
}
var fact_names := []
var rules := {
	# "rule name": [ <number of provided args>, <number of temporary args>, <logic tree> ]
}







var re_fact_statement = RegEx.new()
var re_function = RegEx.new()
var re_rule_definition = RegEx.new()
var re_fact_or_rule = RegEx.new()
var re_expression_term = RegEx.new()


func _init():
	re_fact_statement.compile("^(?<f>[a-z_][a-zA-Z0-9_]*) *[\\[(](?<p>(?: *[a-zA-Z_][a-zA-Z0-9_]* *,?)+)[\\])]\\.?$")
	re_function.compile("^(?<f>[a-z_][a-zA-Z0-9_]*) *\\((?<p>(?: *[A-Z][a-zA-Z0-9]* *,?)*)\\)\\.?$")
	re_rule_definition.compile("[a-z_][a-zA-Z0-9_]* ?[({][a-zA-Z_, ]+[})] *:- *[\\w \\(\\)\\[\\]{},;!=<>%]+")
	re_fact_or_rule.compile("(?<e>!)?(?<n>[a-z_][a-zA-Z0-9_]*)? *(?<b>[\\(\\[{])(?<p>[a-zA-Z0-9_, =<>-]+)[\\]\\)}]")
	re_expression_term.compile("(?<a>[a-zA-Z0-9]+) *(?<o>=|!=|<|<=|>|>=| LIKE ) *(?<b>[a-zA-Z0-9\\?\\*%]+)")



func is_capitalized_var(text: String) -> bool:
	if text.length() == 0: return false
	var c = text.unicode_at(0)
	return (c > 0) and (c >= FIRST_CAPITAL_CHAR) and (c <= LAST_CAPITAL_CHAR)



func _is_literal(text: String) -> bool:
	# Returns true if first character is lowercase, or single quote with next char as lowercase
	if text.length() == 0:
		return false

	var first_char_ord = text.unicode_at(0)
	if first_char_ord == 0x27: # single quote
		first_char_ord = text.unicode_at(1)
	return ( (first_char_ord >= 0x61) and (first_char_ord <= 0x7A) ) or (first_char_ord in [0x27, 0x5F]) # lowercase letters or '_




func _arg_combination_assembler(iterables: Array, output: Array, path: Array = []):
	# When called without passing a path, runs a recursive call tree
	# filling output with arrays of all possible combinations of the iterables
	
	var level = path.size()
	
	if level == iterables.size():
		output.append(path)
		return
	
	var items_in_level: Array = iterables[level]
	for item in items_in_level:
		_arg_combination_assembler(iterables, output, path + [item])
	return


func _local_args_assembler(args: Array, num_internal_vars: int = 0) -> Array:
	# Generates the iterable array for combinations
	# E.g. for args = ["alice", "bob"] and num_internal_vars = 1, generates:
	# [["alice", "bob", "arg1"], 
	#  ["alice", "bob", "arg2"], 
	#  ["alice", "bob", "arg3"], 
	#  ...                      ]
	# where "arg1", "arg2", "arg3" etc are the elements in objects
	
	var result := []
	
	var local_iterables := []
	var local_args := []
	for arg in args:
		local_iterables.append([arg])
	for i in range(num_internal_vars):
		local_iterables.append(objects)
	
	_arg_combination_assembler(local_iterables, result)
	
	return result





func _rule_tester_test_fact(fact_name: String, args: Array) -> bool:
	# Tests one specific literal combination against facts.
	# Args must be all literal
	if not fact_name in fact_names:
		return false
	return (args in facts[fact_name])


func _rule_tester_test_rule(rule, args: Array) -> Array:
	# Tests one specific literal combination against a particular rule
	# Args must be all literal
	# if the rule has internal variables, they will be iterated in a loop
	# (this is very inefficient)
	
	var num_provided_args := 0
	var num_temporary_args := 0
	var rule_body: Array
	
	if rule is String:
		if not rule in rules:
			print("Rule not found")
			return []
		num_provided_args = rules[rule][0]
		num_temporary_args = rules[rule][1]
		rule_body = rules[rule][2]
	
	elif (rule is Array) and (rule.size() == 4):
		num_provided_args = rule[0]
		num_temporary_args = rule[1]
		rule_body = rule[2]
	
	else:
		print("rule param not understood:")
		print(JSON.stringify(rule, "    "))
		return []
	
	if args.size() != num_provided_args:
		return []
	
	# Assemble list of arguments for this particular item
	var local_args: Array = _local_args_assembler(args, num_temporary_args)
	var valid_results := []
	
	for local_arg in local_args:
		# Inside here, all params are literals and this block
		# runs once for each possible combination
		
		for or_block: Array in rule_body:
			var or_block_value := true
			for and_item: Dictionary in or_block:
				# Any AND block returning false inside an OR block invalidates the
				# whole OR block where it is
				
				# local_arg is the list of arguments to the whole rule
				# local_params is the subset being provided to this specific element
				# e.g. for rule my_rule(A, B, C):- fact1[A, C], fact2[C, B]
				# being iterated for local_arg = ["alice", "bob", "ciara"], and this and_item
				# being the first one, then local_params = ["alice", "ciara"]
				
				var is_except: bool = and_item["is_except"] # logical NOT
				
				var local_params := []
				for param_item in and_item["params"]:
					# if param_item is an int, it's an index; if String, it's a literal instead
					if param_item is int:
						local_params.append(local_arg[param_item])
					elif param_item is String:
						local_params.append(param_item)
				
				match and_item["type"]:
					"fact":
						# fails if _rule_tester_test_fact returns false (is_except inverts it)
						if _rule_tester_test_fact(and_item["name"], local_params) == (true if is_except else false):
							or_block_value = false
							break
					"rule":
						# fails if _rule_tester_test_rule returns empty (is_except inverts it)
						if (_rule_tester_test_rule(and_item["name"], local_params) == []) == (false if is_except else true):
							or_block_value = false
							break
				
			
			# If nothing returned false, it means this OR block returned true
			# one true OR block is enough to validate a true answer
			if or_block_value:
				if not local_arg in valid_results:
					valid_results.append(local_arg)
				break
	
	
	return valid_results
	



func _parse_fact_source(text: String):
	var re_res : RegExMatch = re_fact_statement.search(text.strip_edges())
	if not re_res:
		last_error_message = "Expression not understood"
		return false
	if (not "f" in re_res.names) or (not "p" in re_res.names):
		return false
	var fact_name = re_res.strings[re_res.names["f"]]
	var params_str = re_res.strings[re_res.names["p"]]
	var params = params_str.split(",")
	for i in range(params.size()):
		params[i] = params[i].strip_edges()
	
	var items := []
	for item in params:
		items.append(item)
	
	add_fact(fact_name, items)
	
	return true


func _parse_function(text: String) -> Array:
	# text is a String with a function in the form "function_name(Arg1, Arg2, ...)"
	# Arguments must start with uppercase letters
	# Used as head for rule definition
	
	var re_res = re_function.search(text)
	if not re_res:
		return []
	
	var head = re_res.get_string()
	head = head.left( head.length()-1 ).split("(", true, 1)
	
	var head_name = head[0].strip_edges()
	if " " in head_name:
		return []
	
	var params = head[1].strip_edges().split(",")
	var head_params = []
	for i in range(params.size()):
		var this_param = params[i].strip_edges()
		if (" " in this_param):
			return []
		if this_param != "":
			#head_params.append( ELOG_VAR_PREFIX+this_param )
			head_params.append( this_param )
	
	return [head_name, head_params]


func _extract_terms(text: String) -> Array:
	# Converts the terms from input in canonical form
	# and generates logical tree
	# [ [A, B, C], [D, E, F] ] -> (A and B and C) or (D and E and F)
	var result := []
	var param_list := []
	var or_lines = text.strip_edges().split(";")
	
	for or_line in or_lines:
		or_line = or_line.strip_edges()
		var re_res = re_fact_or_rule.search_all(or_line)
		if not re_res:
			print("re error")
			return []
		var this_or = []
		
		for re_item in re_res:
			var is_except = ( ("e" in re_item.names) and (re_item.strings[ re_item.names["e"] ] == "!") )
			var b = re_item.strings[ re_item.names["b"] ]
			var p = re_item.strings[ re_item.names["p"] ]
			
			if not "n" in re_item.names:
				# BOOLEAN EXPRESSION
				this_or.append({
					"expression": p,
					"is_except": is_except,
					"type": "expr",
				})
			
			else:
				# FUNCTION CALL
				var n = re_item.strings[ re_item.names["n"] ]
				#print("n=",n," p=",p,"   b=",b)
				
				var params = p.strip_edges().split(",")
				var func_params := []
				for i in range(params.size()):
					var this_param = params[i].strip_edges()
					for forbidden_char in [" ","<",">","=","-","!"]:
						if (forbidden_char in this_param):
							return []
					
					#if is_capitalized_var(this_param):
						#this_param = ELOG_VAR_PREFIX+this_param
					func_params.append( this_param )
					if not this_param in param_list:
						param_list.append( this_param )
		
				var p_type: String = FUNC_TYPE.get(b, "auto")
				if p_type == "auto":
					if n in fact_names:
						p_type = "fact"
					elif n in rules:
						p_type = "rule"
					else:
						print("Could not identify type for: ", n)
						return []
				
				this_or.append({
					"name":n,
					"params":func_params,
					"is_except": is_except,
					"type": p_type
				})
		
		
		result.append(this_or)
	
	return [result, param_list]


func _body_vars_to_indices(var_map: Array, body: Array):
	for or_block: Array in body:
		for and_item: Dictionary in or_block:
			var params: Array = and_item["params"]
			for i in range(params.size()):
				if params[i] in var_map:
					params[i] = var_map.find(params[i]) 


func _parse_rule_source(text: String, force_replace_rule: bool = false):
	# Parses input declaring a rule, generates the rule logical tree,
	# and adds to rule Dictionary
	
	var result := []
	
	if text.count(":-") != 1:
		return [] # Invalid
	
	var head_body = text.strip_edges().split(":-", true, 1)
	var head = _parse_function(head_body[0].strip_edges())
	# head = [name, params]
	if head.size() < 2:
		last_error_message = "Expression not understood"
		print("Error parsing head: ",head_body[0])
		return []
	
	if (head[0] in fact_names):
		print("Head already exists as fact")
		return []
	
	if (head[0] in rules) and (not force_replace_rule):
		print("Head already exists as rule")
		return []
	
	var is_query = (head[0] == "_")
	var is_truefalse_question = false
	
	var terms = _extract_terms(head_body[1].strip_edges())
	if terms.size() == 0:
		print("There are no terms to parse")
		return []
	
	# Logical canonical format: array of array of dicts
	# outer array is OR, inner array is AND, dicts are the items
	# (items are facts or rules)  
	var body: Array = terms[0] 
	var param_list: Array = terms[1]
	var unused_vars := []
	for param in param_list:
		if (not param in head[1]) and (is_capitalized_var(param)):
			unused_vars.append(param)
	
	
	# var_map is just an Array of all the variable names provided by the user
	# the ones in the head come first, followed by internal ones
	# e.g. in: my_rule(A, C):- fact1[A, B], fact2[B, C]
	# var_map = ["A", "C", "B"]
	# It is used to convert variable names to indices
	var var_map: Array = head[1] + unused_vars
	
	_body_vars_to_indices(var_map, body)
	
	if is_query:
		# For a query,head[1] *MUST* be empty. No vars are being passed, only
		# literals. if there is a var, it must be assumed as temporary internal
		if head[1].size() > 0:
			print("head[1] not empty")
			return []
	
	else:
		rules[head[0]] = [
			head[1].size(),
			unused_vars.size(),
			body,
			text
		]
	
	#return [head[0], head[1], unused_vars, body] 
	return [head[1].size(), unused_vars.size(), body, unused_vars] 


func add_fact(fact_name: String, items: Array) -> bool:
	if fact_name in rules:
		return false
	
	if not fact_name in facts:
		facts[fact_name] = []
	if not fact_name in fact_names:
		fact_names.append(fact_name)
	
	if items in facts[fact_name]:
		return false
	
	for i in range(items.size()):
		if not items[i] in objects:
			objects.append(items[i])
	
	facts[fact_name].append(items)
	
	return true


func regen_known_objects():
	objects.clear()
	for fact_name in facts:
		for fact_row in facts[fact_name]:
			for i in range(0, fact_row.size()): # forward compatible to item[0] being metadata
				var obj = fact_row[i]
				if not obj in objects:
					objects.append(obj)


func remove_fact(fact_name: String) -> bool:
	if not fact_name in rules:
		return false
	
	fact_names.erase(fact_name)
	
	if fact_name in facts:
		facts.erase(fact_name)
	
	regen_known_objects()
	
	return true


func remove_rule(rule_name: String) -> bool:
	if not rule_name in rules:
		return false
	
	rules.erase(rule_name)
	
	return true


func get_list_of_facts() -> Array:
	return fact_names.duplicate()


func get_list_of_rules() -> Array:
	return rules.keys()


func get_list_of_objects() -> Array:
	return objects.duplicate()


func get_objects_with_fact(fact_name: String) -> Array:
	var result := []
	
	if fact_name in facts:
		for item in facts[fact_name]:
			for obj in item:
				if not obj in result:
					result.append(obj)
	
	return result


func get_fact_data(fact_name: String) -> Array:
	var result := []
	
	if fact_name in facts:
		for item: Array in facts[fact_name]:
			var row := {}
			for i in range(item.size()):
				row[ "X%d" % (i+1) ] = item[i]
			result.append(row)
	return result


func get_rule_data(rule_name: String) -> Array:
	if not rule_name in rules:
		return []
	
	return rules[rule_name].duplicate(true)


func get_facts_with_object(object: String) -> Array:
	# This is a more expensive call as it loops 
	# through all objects of all facts
	
	var result := []
	
	for fact_name in facts:
		var fact_contains_object := false
		for item in facts[fact_name]:
			for obj in item:
				if obj == object:
					if not fact_name in result:
						result.append(fact_name)
					fact_contains_object = true
					break
			
			if fact_contains_object:
				break
	
	return result


func get_rule_function_thumb(rule_name: String) -> String:
	if not rule_name in rules:
		return ""
	
	var rule: Array = rules[rule_name]
	
	var args := []
	for i in range(rule[0]):
		args.append("X%d" % (i+1))
	
	return "%s (%s)" % [rule_name, ", ".join(args)]


func get_list_of_rule_thumbs() -> Array:
	var result := []
	for rule_name in rules:
		result.append(get_rule_function_thumb(rule_name))
	return result


func define(text: String):
	var new_text = text.strip_edges()
	
	if new_text.ends_with("?"):
		# define() is not intended to be used for queries,
		# but if it is, we handle it
		new_text = new_text.left(new_text.length()-1)
		return query(new_text)
	
	elif new_text.ends_with("."):
		new_text = new_text.left(new_text.length()-1)
		return create_fact_or_rule(new_text)
	
	else:
		return false

func create_fact_or_rule(text: String, force_replace_rule: bool = false) -> bool:
	var re_res = re_fact_statement.search(text)
	if re_res:
		return _parse_fact_source(text)
	
	re_res = re_rule_definition.search(text)
	if re_res:
		return (_parse_rule_source(text, force_replace_rule).size() > 0)
	
	return false


func query(text: String) -> Array:
	var query_text = "_():- "+text
	var query_rule_data = _parse_rule_source(query_text)
	if query_rule_data.size() == 0:
		return []
	
	var valid_results: Array = _rule_tester_test_rule(query_rule_data, [])
	
	var result := []
	var output_vars: Array = query_rule_data[3]
	
	for result_set in valid_results:
		var set_dict := {}
		for i in range(output_vars.size()):
			set_dict[output_vars[i]] = result_set[i]
		result.append(set_dict)
	
	# If it's a varibleless query, e.g. all terms are literal, then
	# valid_results == [] means false
	# valid_results == [[]] means true, and result will contain one empty Dictionary
	
	return result
