# Elog

_Godot addon for logic inference (PROLOG style)_

----

Elog is an backward-chaining inference machine written entirely in GDScript with no external dependencies, based (while not identical) on PROLOG syntax.

You can add facts, define rules using those facts, and then query the system to retrieve conclusions. It achieves the same results as if you had written `if-then-else` clauses while iterating over your data, but it creates the `if`'s dynamically, on the fly, as you ask things (or, for the database folks, it's like a SQL SELECT query, but with the WHERE clause assembled on the fly by the system).

Think of it as a scripted language and interpreter running one-liners interactively inside your game/application, specialized in reaching logical conclusions based on relationships between data. Something like if a script interpreter and a database had a child.

_(For a better understanding on the theory used by Elog, you can search about backward-chaining inference machines, such as PROLOG. Elog is much simpler and more limited, though.)_

----

There is a scene `res://addons/elog/tests/elog_console.tscn` which teaches how to use the syntax. The TL;DR is below:

There are _facts_ and _rules_. 

- Facts are immutable and independent: if apple is a fruit, apple is always a fruit, to the end of times.
- Rules are logical inferences based on facts or other rules. E.g. if you have a fact defining something is a person, and another fact defining if a person is an earthling, you can have a rule "alien" defined as "is a person, and is not an earthling". 

Think of facts as variables, and rules as expressions in an "IF" block.

You can perform _queries_, which have the same syntax of rules, but instead of just evaluating as true or false, they return all the possible data combinations which satisfy the condition (exactly like a SQL SELECT clause).


## Facts and Objects

To define a fact, declare the name of the fact, and a sequence of values as arguments. The interpretation of the fact is up to you, Elog only cares about a combination of values linked to a keyword (order matters!). E.g., you can declare a fact named "father" with the values "peter" and "mary", and another fact with the same name, for "peter" and "john":

```
        father[peter,mary].
        father[peter,john].
```

which your application can interpret as Peter being father to both Mary and John.

Declaring facts also declares the objects used in the declarations, so the lines above will register objects "peter", "mary" and "john".

Replace the period for an exclamation mark, and you are performing a query. If all arguments are provided as literals, it will return true or false, e.g.:

```
        father[peter,mary]?
```

returns true, while

```
        father[peter,ralph]?
```

returns false.

You can replace any number of values for an open variable (identified by starting with an uppercase letter), and the result of the query will instead be the list of data sets which satisfy that fact. E.g.:

```
        father[peter,X]?
```

will list children of Peter, while

```
        father[X,Y]?
```

will return all father-child pairs.


## Rules

You can declare rules, giving a name and some arguments, and then the expression to compute the result, which is a logic expression using facts and/or other rules.

Example, if we have the fact `parent[A, B]`, we can define the rule `grandparent` as:

```
        grandparent(A, B):- parent[A, X], parent[X, B].
```

for an AND logic. For an OR logic example, we can have the facts `father` and `mother`, and `parent` being actually a rule, defined as:

```
        parent(A, B):- mother[A, B]; father[A, B].
```

A more complex example: a patient must take medicine if they have a runny nose, and either have fever, or is sneezing but does not have an allegy (assuming we have the facts `runny_nose`, `fever`, `sneezing`, `alergy` all with one argument for patient). Elog uses sum of minterms notation, so the condition "runny nose AND ( fever OR (sneezing AND NOT allergy) )" should be unpacked to: "(runny nose AND fever) OR (runny nose AND sneezing AND NOT allergy)":

```
        must_take_medicine(Patient):- runny_nose(Patient), fever(Patient); runny_nose(Patient), sneezing(Patient), !allergy(Patient).
```


## Queries

A query is a question made to the inference machine. You can provide direct values or open variables.

If all the arguments present in a query are objects, the result will be either true or false. E.g. the queries:

```
        father(peter, john)?
        father(peter, alfred)?
```

would return true and false respectively (for the example facts shown previously).

The query below will show if Peter needs to take medicine, given the conditions defined:

```
        must_take_medicine(peter)?
```

If there are open variables in a query, all the existing objects will be tested against the query to check which ones satisfy the condition.

E.g., the query below will show a list of all the grandchildren of Peter:

```
        grandparent(peter, X)?
```

While the query below will show a list of grandparents of Peter:

```
        grandparent(X, peter)?
```

The query below will show all the patients who need to take medicine, given the conditions defined:

```
        must_take_medicine(X)?
```

----

## Test Scene with Console

The addon comes with a test scene (`res://addons/elog/tests/elog_console.tscn`) with a help window explaining all the syntax, as well as an interactive console, with side boxes to inspect the internal data as you operate. the script in that scene also teaches how to call the API.

![image](https://github.com/user-attachments/assets/6fa34cfb-16d1-4e5b-b485-9fad25c7cb60)
