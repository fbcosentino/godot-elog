extends Control

@onready var elog := $Elog

@onready var objects_itemlist := $Objects/ItemList
@onready var facts_itemlist := $Facts/ItemList
@onready var rules_itemlist := $Rules/ItemList

@onready var input_lineedit := $Console/LineEdit
@onready var table := $Console/ScrollContainer/Table

@onready var rule_tree := $RuleDetails/StructureTree

func refresh_objects():
	objects_itemlist.clear()
	for obj in elog.get_list_of_objects():
		objects_itemlist.add_item(obj, null, false)


func refresh_facts():
	facts_itemlist.clear()
	for fact_name in elog.get_list_of_facts():
		facts_itemlist.add_item(fact_name, null, false)


func refresh_rules():
	rules_itemlist.clear()
	for rule_thumb in elog.get_list_of_rule_thumbs():
		rules_itemlist.add_item(rule_thumb, null, false)


func _ready() -> void:
	$RuleDetails.hide()
	call_deferred("setup")

func setup():
	await get_tree().create_timer(0.1).timeout
	
	# If you want to add facts via code without having to define from strings,
	# you can use Elog's method add_fact() passing the fact name and
	# an Array of String values. E.g., instead of using
	#     elog.define("father[peter, mary].")
	# you can call
	#     elog.add_fact("father", ["peter", "mary"])
	
	elog.define("father[peter, mary].")
	elog.define("mother[linda, mary].")
	elog.define("father[peter, john].")
	elog.define("mother[mary, jane].")
	
	
	# The internal logic to add a rule is not straight-forward, so if you
	# want to programatically add rules, you're better off compiling your
	# rules into strings like the ones below and calling define() for them.
	
	elog.define("parent(A,B):- father(A,B); mother(A,B).")
	elog.define("grandparent(A,B):- parent(A,C), parent(C,B).")
	elog.define("children_of_peter(A):- parent(peter,A).")
	
	refresh_all()


func refresh_all():
	refresh_objects()
	refresh_facts()
	refresh_rules()




func elog_query(query_text: String):
	var result = elog.query(query_text)
	
	if result is Array:
		# A valid result from elog.query() will always be an Array.
		# An empty array means there are no results satisfying the query,
		# which means "none" if you provided an open variable (e.g. X)
		# or means "false" if you provided all literal values.
		# If there are valid results, each item in the Array will be a 
		# Dictionary.
		# If you provided open variables, (e.g. X, Y), they will be the keys
		# for the values which satisfy the query, e.g.:
		#     result = [ 
		#                   {"X": "john", "Y": "mary"}, 
		#                   {"X": "john", "Y": "jane"}
		#              ]
		# Literals provided will not show up as there are no keys for them,  
		# which means if you provided all literals with no open variables,
		# a successful result will be an empty dictionary, e.g.:
		#     result = [ { } ]     -> this means the query is "true"
		
		update_table(result)


func update_table(result: Array):
	table.clear()
	if result.size() > 0:
		if (result.size() == 1) and (result[0].size() == 0):
			# returned an empty Dictionary, means the result is "true"
			table.add_item("(True)")
		
		else:
			var titles: Array = result[0].keys()
			table.max_columns = titles.size()
			for title in titles:
				table.add_item("   [ %s ]   " % title)
			
			for row: Dictionary in result:
				for title in titles:
					table.add_item(row[title])
	else:
		table.add_item("(Empty results or false)")


func _on_input_text_submitted(new_text: String) -> void:
	input_lineedit.text = ""
	
	# define() identifies automatically if you sent a query instead of a
	# definition, and redirects the call to query() instead
	# So we can use define() as a "one method fits all" kinda thing
	var result = elog.define(new_text)
	
	if result is Array:
		update_table(result)
		
	refresh_all()


func _on_objects_item_list_item_activated(index: int) -> void:
	var object: String = $Objects/ItemList.get_item_text(index)
	var title: String = "Facts containing: " + object
	var result := []
	var objs: Array = elog.get_facts_with_object(object)
	for obj in objs:
		result.append({title: obj})
	update_table(result)


func _on_facts_item_list_item_activated(index: int) -> void:
	var fact_name: String = $Facts/ItemList.get_item_text(index)
	update_table(elog.get_fact_data(fact_name))
	#var title: String = "Objects contained in: " + fact_name
	#var result := []
	#var objs: Array = elog.get_objects_with_fact(fact_name)
	#for obj in objs:
		#result.append({title: obj})
	#update_table(result)


func update_rule_tree(rule_name: String, rule_body: Array, arg_list: Array):
	rule_tree.clear()
	rule_tree.set_column_title(0, "Item")
	rule_tree.set_column_title(1, "Type")
	rule_tree.set_column_title(2, "Note")
	rule_tree.set_column_custom_minimum_width(0, 160)
	rule_tree.set_column_custom_minimum_width(2, 160)
	
	var root: TreeItem = rule_tree.create_item()
	root.set_text(0, rule_name)
	root.set_text(2, "(Groups inside are OR'ed: one resulting true is enough)")
	root.set_custom_font_size(2, 8)
	
	for or_group: Array in rule_body:
		var or_group_treeitem: TreeItem = rule_tree.create_item(root)
		or_group_treeitem.set_text(0, "(Group)")
		or_group_treeitem.set_text(2, "(Items inside are AND'ed: all must result true)")
		or_group_treeitem.set_custom_font_size(2, 8)
		
		for and_item: Dictionary in or_group:
			var and_treeitem: TreeItem = rule_tree.create_item(or_group_treeitem)
			var item_text := ""
			if (and_item["is_except"]):
				item_text += "NOT "
			item_text += and_item["name"]
			
			var args := []
			for arg_index in and_item["params"]:
				if arg_index is int:
					args.append(arg_list[arg_index])
				else:
					args.append(str(arg_index))
			item_text += " (%s)" % ", ".join(args)
			
			and_treeitem.set_text(0, item_text)
			and_treeitem.set_text(1, and_item["type"])
			and_treeitem.set_text(2, "")
			
			and_treeitem.set_text_alignment(1, HORIZONTAL_ALIGNMENT_CENTER)
			and_treeitem.set_custom_font_size(2, 8)
			
			for key in and_item:
				var dict_treeitem: TreeItem = rule_tree.create_item(and_treeitem)
				dict_treeitem.set_text(0, str(key)+": "+str(and_item[key]))
			
			and_treeitem.set_collapsed_recursive(true)


func _on_rules_item_list_item_activated(index: int) -> void:
	var rule_expression: String = $Rules/ItemList.get_item_text(index)
	var rule_elements: Array = rule_expression.split(" ", true, 1)
	var rule_data: Array = elog.get_rule_data(rule_elements[0])
	
	if rule_data:
		var rule_num_provided_args: int = rule_data[0]
		var rule_num_internal_args: int = rule_data[1]
		var rule_body: Array = rule_data[2]
		var rule_def: String = rule_data[3]
		
		$RuleDetails/LabelRuleName.text = rule_elements[0]
		$RuleDetails/LabelArgsProvided.text = str(rule_num_provided_args)
		$RuleDetails/LabelArgsInternal.text = str(rule_num_internal_args)
		$RuleDetails/LabelRuleDefinition.text = rule_def
		
		var arg_list := []
		for i in range(rule_num_provided_args):
			arg_list.append("X%d" % (i + 1))
		for i in range(rule_num_internal_args):
			arg_list.append("Y%d" % (i + 1))
		
		update_rule_tree(rule_elements[0], rule_body, arg_list)
		
		$RuleDetails.show()

func _on_rule_details_btn_close_pressed() -> void:
	$RuleDetails.hide()


func _on_help_btn_close_pressed() -> void:
	$Help.hide()
