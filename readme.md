# DIL (Dlang Interpreted Language) 
A simple embeddable scripting language written in the [D programming language](https://dlang.org/).

## Examples
### Var Declarations
```
/*
 Examples of declaring local variable.
 Declarations must be initialized.
*/
local nothing = void;
local nulled = null;
local integer = 0;
local real = 0.0;
local char = 'c';
local string = "text";
local array = [0,0.0,'c',"text"];
local table = ["hi" : 0, 0 : array];
local func = function(){};
local clss = class {
	this ctor() {}
};
local inst = clss.ctor();
local prop = property {
	get = function() { return integer; };
	set = function(v) { integer = v; };
};

// Global variable.
global glob = 0;
// Global variables are accessed by prepending ':'.
:glob = 1;
```

### Importing Modules
```
local io = :import("std.io");
```

### If Statement
```
local i = :int(io.readln());
if(i < 0)
{
	io.println("negative");
}
else if(i > 0)
{
	io.println("positive");
}
else
	io.println(0);
```

### Loops
```
local j = 0;
lbld: while(true)
{
	//Supports labeled and unlabeled breaks and continues
	if(j < 10)
		continue;
	else if(j > 16)
		break lbld;
	j++;
}

/*
 Language currently doesn't support empty for loops declarations, i.e.
 for(;;) {}
*/
for(local i = 0; i < 16; i++) {}

/*
 foreach supports any value that implement range semantics in the scripting language.
 Including:
 tables
 arrays
 strings
 functions
 class instances that implement:
	advance()
	isEmpty()
	value()
	key() (This one is optional.)
*/
foreach(k,v; ["hi" : "hello", 1 : 0]) {}
```

### Expressions (Similar to [Dlang](https://dlang.org/spec/expression.html))
```
//Standard +-*/%
io.println(1 + 1 - 1 * 1 / 1 % 1);

//Power ^^
io.println(2^^63);

//Append strings
io.println("Hello " ~ "World!");

//Short circuit and/or
io.println(true && "and", false || "or");

//Ternary
io.println(true ? true : false);

//Bitmanip on integers
io.println( 63 & 63 | 0 ^ 64 << 1 >> 1 >>> 1);
```

### Expressions
```
// Function expr
// Language does not support functions as statements.
local func = function(hi,args...)
{
	io.println(hi);

	// args is an optional varargs that behaves like an array.
	foreach(arg; args)
		io.println(arg);
};

func(0,1,2,3,4,5,6,8,9);

// Class expr
local classA = class
{
	local i = void;

	this namedCtor(v)
	{
		i = v;
	}

	local v = property
	{
		get = function { return i; };
		set = function(n) { i = n; };
	};
};

local instA = classA.namedCtor(1);
io.println(instA.v);

// scope keyword returns the current scope as a table.
local i = 0;
io.println(scope["i"]);
```