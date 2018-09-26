module dil.val;

import dil.exception;

final class DilTable
{
	DilVal[DilKey] vals;
	DilTable parentScope;

	this()(DilTable parentScope = null)
	{
		this.parentScope = parentScope;
	}

	DilVal opIndex()(auto ref DilVal idx) @safe
	{
		import core.exception;
		return vals.get(
			DilKey(idx),
			delegate() @safe
			{
				import std.format : format;
				if(parentScope is null)
					throw new DilRangeException(format!"'%s' of type %s is not a key in the table."(idx,idx.type));
				return parentScope.opIndex(idx);
			}()
		);
	}

	DilVal opIndex(T)(T idx)
	if(!is(T == DilVal))
	{
		return this[DilVal(idx)];
	}

	void opIndexAssign()(auto ref DilVal v, auto ref DilVal idx)
	{
		if(shallowContains(idx))
			vals[DilKey(idx)] = v;
		else if(parentScope !is null && parentScope.deepContains(idx))
			parentScope.opIndexAssign(v,idx);
		else
			vals[DilKey(idx)] = v;
	}

	bool shallowContains()(auto ref DilVal idx) @safe
	{
		return (DilKey(idx) in vals) !is null;
	}

	bool shallowContains(T)(T idx)
	if(!is(T == DilVal))
	{
		return shallowContains(DilVal(idx));
	}

	bool deepContains()(auto ref DilVal idx)
	{
		if(shallowContains(idx))
			return true;
		else if(parentScope !is null)
			return parentScope.deepContains(idx);
		else
			return false;
	}

	bool deepContains(T)(T idx)
	if(!is(T == DilVal))
	{
		return deepContains(DilVal(idx));
	}

	void update()(auto ref DilVal key, DilVal delegate() @safe create, DilVal delegate(ref DilVal v) @safe update) @trusted
	{
		vals.update(DilKey(key),create,update);
	}

	string toString()() @safe
	{
		import std.format : format;
		return format!"%s,parentScope=%s"(vals,parentScope);
	}

	DilKey[] keys()() @safe @property
	{
		DilKey[] ret;
		if(parentScope !is null)
			ret = parentScope.keys;
		
		outer: foreach(ref k; vals.byKey)
		{
			foreach(ref v; ret)
				if(v == k)
					continue outer;
			ret ~= k;
		}

		return ret;
	}

	size_t length()() @property
	{
		return keys().length;
	}
}

final class DilCtor : IDilCallable
{
	IDilCallable cllbl;
	IDilClass clss;

	this()(IDilCallable cllbl, IDilClass clss)
	{
		this.cllbl = cllbl;
		this.clss = clss;
	}

	IDilCallable context(DilVal val)
	{
		return new DilCtor(cllbl,val.get!IDilClass);
	}

	DilVal call(DilVal[] args...)
	{
		auto inst = clss.constructInstance();
		cllbl.context(DilVal(inst.instData)).call(args);
		return DilVal(inst);
	}

	size_t toHash() inout @trusted
	{
		return cast(size_t)cast(void*)this;
	}
}

interface IDilClass
{
	void constructData(DilTable tbl) @safe;
	DilInst constructInstance() @safe;
	DilVal appendParent(DilVal v) @safe;
	IDilCallable[dstring] ctors() pure nothrow @safe @nogc @property;

	final DilVal opBinary(string op)(DilVal v)
	{
		static if(op == "~")
		{
			return this.appendParent(v);
		}
		else
		{
			throw new DilUnsupportedOpException("Classes only support '~'.");
		}
	}

	string toString() @safe;
}

final class DilClass : IDilClass
{
	DilVal[DilKey] memberVars;
	IDilClass[] parents;
	IDilCallable[dstring] _ctors;
	DilTable parentScope;

	this()(DilVal[DilKey] memberVars, DilTable parentScope, IDilCallable[dstring] _ctors)
	{
		this.memberVars = memberVars;
		this.parentScope = parentScope;
		
		foreach(k,v; _ctors)
		{
			DilCtor c = cast(DilCtor)v;
			if(c !is null)
				this._ctors[k] = c.context(DilVal(this));
			else
				this._ctors[k] = new DilCtor(v,this);
		}
	}

	void constructData(DilTable tbl) @safe
	{
		foreach(k, ref v; memberVars)
		{
			if(v.type == DilVal.Type.callable)
				tbl.update(k.val,() => DilVal(v.get!IDilCallable.context(DilVal(tbl))),delegate(ref DilVal d){ return d; });
			else if(v.type == DilVal.Type.prop)
				tbl.update(k.val,() => DilVal(v.get!DilProperty.context(tbl)),delegate(ref DilVal d){ return d; });
			else
				tbl.update(k.val,() => v,delegate(ref DilVal d){ return d; });
		}

		foreach(clss; parents)
			clss.constructData(tbl);
		
		tbl.parentScope = parentScope;
	}
	
	DilInst constructInstance() @trusted
	{
		DilInst inst;
		inst.instData = new DilTable;
		constructData(inst.instData);
		inst.instData.vals.rehash;
		inst.classData = this;
		return inst;
	}

	DilVal appendParent(DilVal v) @safe
	{
		if(v.type == DilVal.Type.class_)
		{
			DilClass clss = new DilClass(memberVars,parentScope,ctors);
			clss.parents ~= v.get!IDilClass;
			return DilVal(clss);
		}
		else if(v.type == DilVal.Type.table)
		{
			DilClass clss = new DilClass(memberVars.dup,parentScope,ctors);
			DilTable tbl = v.get!DilTable;
			foreach(ref k; tbl.keys())
				clss.memberVars[k] = tbl[k.val];
			return DilVal(clss);
		}
		else
			throw new DilUnsupportedOpException("Can only append tables and classes to classes.");
	}

	IDilCallable[dstring] ctors() { return _ctors; }

	override string toString() @trusted { import std.format; return format!"%s"(_ctors); }
}

struct DilInst
{
	DilTable instData;
	IDilClass classData;

	size_t toHash() nothrow @trusted const
	{
		import core.internal.hash : hashOf;
		return instData.hashOf + classData.hashOf;
	}

	string toString()() @safe
	{
		if(instData.shallowContains("toString"d))
		{
			DilVal v = instData["toString"d];
			if(v.type == DilVal.Type.callable)
				return v.get!IDilCallable.call().toString;
			else
				return v.toString;
		}
		else
		{
			return instData.toString;
		}
	}

	real opCmp(DilVal rhs)
	{
		dilEnforce!DilUnsupportedOpException(instData.shallowContains("opCmp"d),"Instance does not support opCmp.");
		DilVal v = instData["opCmp"d];
		return cast(real)v.get!IDilCallable.call(rhs);
	}

	DilVal opBinary(string op)(DilVal rhs)
	{
		import std.meta : AliasSeq;
		template Pair(string oper, dstring opFnc)
		{
			enum operator = oper;
			enum fnc = opFnc;
		}
		static foreach(P; AliasSeq!(
			Pair!("+","opAdd"),
			Pair!("-","opSub"),
			Pair!("*","opMul"),
			Pair!("/","opDiv"),
			Pair!("%","opMod"),
			Pair!("&","opAnd"),
			Pair!("|","opOr"),
			Pair!("^","opXor"),
			Pair!("<<","opShl"),
			Pair!(">>","opShr"),
			Pair!(">>>","opUShr"),
			Pair!("~","opCat"),
			Pair!("in","opIn"),
			Pair!("^^","opPow")
		))
		{
			static if(op == P.operator)
			{
				import std.conv : text;
				enum msg = "Instance does not support '"~P.fnc.text~"' for op '"~P.operator~"'.";
				dilEnforce!DilUnsupportedOpException(instData.shallowContains(P.fnc),msg);
				return instData[P.fnc].get!IDilCallable.call(rhs);
			}
		}
	}

	DilVal opUnary(string op)()
	{
		import std.meta : AliasSeq;
		template Pair(string oper, dstring opFnc)
		{
			enum operator = oper;
			enum fnc = opFnc;
		}
		static foreach(P; AliasSeq!(
			Pair!("+","opPos"),
			Pair!("-","opNeg"),
			Pair!("~","opCom"),
			Pair!("!","opNot")
		))
		{
			static if(op == P.operator)
			{
				import std.conv : text;
				enum msg = "Instance does not support '"~P.fnc.text~"' for op '"~P.operator~"'.";
				dilEnforce!DilUnsupportedOpException(instData.shallowContains(P.fnc),msg);
				return instData[P.fnc].get!IDilCallable.call();
			}
		}
	}

	DilVal opIndex()(DilVal ndx)
	{
		/+dilEnforce!DilUnsupportedOpException(instData.shallowContains("opIndex"d),"Instance does not support opIndex.");
		DilVal v = instData["opIndex"d];
		return v.get!IDilCallable.call(ndx);+/
		return instData[ndx];
	}

	void opIndexAssign()(DilVal rhs, DilVal ndx)
	{
		instData[ndx] = rhs;
	}

	size_t length()
	{
		dilEnforce!DilUnsupportedOpException(instData.shallowContains("length"d),"Instance does not support opCmp.");
		DilVal v = instData["length"d];
		if(v.type == DilVal.Type.prop)
			return cast(size_t)cast(ptrdiff_t)v.get!DilProperty.getter.call();
		return cast(size_t)cast(ptrdiff_t)v.get!IDilCallable.call();
	}
}

interface IDilCallable
{
	IDilCallable context(DilVal val) @safe;

	DilVal call(DilVal[] args...) @safe;

	size_t toHash() @safe nothrow inout;
}

final class DilDDelegate : IDilCallable
{
	alias Delegate = DilVal delegate(DilTable context, DilVal[] args...) @safe;

	Delegate deleg;
	DilTable cntxt;

	this()(Delegate deleg,DilTable cntxt = null)
	{
		this.deleg = deleg;
		this.cntxt = cntxt;
	}

	IDilCallable context(DilVal val)
	{
		return new DilDDelegate(deleg,val.get!DilTable);
	}

	DilVal call(DilVal[] args...)
	{
		return deleg(cntxt,args);
	}

	size_t toHash() inout @trusted
	{
		return cast(size_t)cast(void*)this;
	}
}

struct DilProperty
{
	IDilCallable getter;
	IDilCallable setter;

	DilProperty context()(DilTable val)
	{
		return DilProperty(getter is null ? null : getter.context(DilVal(val)), setter is null ? null : setter.context(DilVal(val)));
	}

	size_t toHash() nothrow @safe const
	{
		size_t hsh = 0;
		if(getter !is null)
			hsh += getter.toHash;
		if(setter !is null)
			hsh += setter.toHash;
		return hsh;
	}
}
import dil.rng : IDilRng;
import std.traits : isIntegral, isFloatingPoint, isSomeString;
struct DilVal
{
	this()(DilVal v)
	{
		this = v;
	}

	this(T)(T v)
	if(!is(T == DilVal))
	{
		set(v);
	}

	enum Type
	{
		void_, bool_, int_, real_, char_, string_, array, table, inst, class_, callable, prop, rng, userObject, null_
	}

	import std.meta : AliasSeq;
	alias ImplTypes = AliasSeq!(bool,ptrdiff_t,real,dchar,dstring,DilVal[],DilTable,DilInst,IDilClass,IDilCallable,DilProperty,IDilRng,Object,typeof(null));

	private union
	{
		bool b;
		ptrdiff_t i;
		real r;
		dchar c;
		dstring str;
		DilVal[] arr;
		DilTable tbl;
		DilInst inst;
		IDilClass clss;
		IDilCallable callable;
		DilProperty prop;
		IDilRng rng;
		Object userObject;
	}
	Type type;

	void set(T)(T v)
	{
		static if(is(T == typeof(null)))
		{
			tbl = null;
			type = Type.null_;
		}
		else static if(is(T == bool))
		{
			b = v;
			type = Type.bool_;
		}
		else static if(isIntegral!T)
		{
			i = v;
			type = Type.int_;
		}
		else static if(isFloatingPoint!T)
		{
			r = v;
			type = Type.real_;
		}
		else static if(is(T : dchar))
		{
			c = v;
			type = Type.char_;
		}
		else static if(isSomeString!T)
		{
			import std.conv : dtext;
			str = v.dtext;
			type = Type.string_;
		}
		else static if(is(T == dstring))
		{
			str = v;
			type = Type.string_;
		}
		else static if(is(T == DilVal[]))
		{
			arr = v;
			type = Type.array;
		}
		else static if(is(T == DilTable))
		{
			if(v is null)
			{
				tbl = null;
				type = Type.null_;
			}
			else
			{
				tbl = v;
				type = Type.table;
			}
		}
		else static if(is(T == DilInst))
		{
			if(v.instData is null)
			{
				tbl = null;
				type = Type.null_;
			}
			else
			{
				inst = v;
				type = Type.inst;
			}
		}
		else static if(is(T : IDilClass))
		{
			assert(v !is null);
			clss = v;
			type = Type.class_;
		}
		else static if(is(T : IDilCallable))
		{
			assert(v !is null);
			callable = v;
			type = Type.callable;
		}
		else static if(is(T == DilProperty))
		{
			assert(v.getter !is null || v.setter !is null);
			prop = v;
			type = Type.prop;
		}
		else static if(is(T : IDilRng))
		{
			assert(v !is null);
			rng = v;
			type = Type.rng;
		}
		else static if(is(T : Object))
		{
			assert(v !is null);
			userObject = v;
			type = Type.userObject;
		}
		else
			static assert(0,"'"~T.stringof~"' is not compatible.");
	}

	inout(T) get(T)() @trusted inout
	{
		static if(is(T == bool))
		{
			enum msg = "Does not contain a bool.";
			dilEnforce!DilGetException(type == Type.bool_,msg);
			return b;
		}
		else static if(is(T == ptrdiff_t))
		{
			enum msg = "Does not contain a ptrdiff_t.";
			dilEnforce!DilGetException(type == Type.int_,msg);
			return i;
		}
		else static if(is(T == real))
		{
			enum msg = "Does not contain a real.";
			dilEnforce!DilGetException(type == Type.real_,msg);
			return r;
		}
		else static if(is(T == dchar))
		{
			enum msg = "Does not contain a dchar.";
			dilEnforce!DilGetException(type == Type.char_,msg);
			return c;
		}
		else static if(is(T == dstring))
		{
			enum msg = "Does not contain a dstring.";
			dilEnforce!DilGetException(type == Type.string_,msg);
			return str;
		}
		else static if(is(T == string))
		{
			import std.conv : text;
			enum msg = "Does not contain a dstring.";
			dilEnforce!DilGetException(type == Type.string_,msg);
			return str.text;
		}
		else static if(is(T == wstring))
		{
			import std.conv : wtext;
			enum msg = "Does not contain a dstring.";
			dilEnforce!DilGetException(type == Type.string_,msg);
			return str.wtext;
		}
		else static if(is(T == DilVal[]))
		{
			enum msg = "Does not contain an array.";
			dilEnforce!DilGetException(type == Type.array,msg);
			return arr;
		}
		else static if(is(T == DilTable))
		{
			enum msg = "Does not contain a table.";
			dilEnforce!DilGetException(type == Type.table,msg);
			return tbl;
		}
		else static if(is(T == DilInst))
		{
			enum msg = "Does not contain a class instance.";
			dilEnforce!DilGetException(type == Type.inst,msg);
			return inst;
		}
		else static if(is(T == IDilClass))
		{
			enum msg = "Does not contain a class.";
			dilEnforce!DilGetException(type == Type.class_,msg);
			return clss;
		}
		else static if(is(T == IDilCallable))
		{
			enum msg = "Does not contain a callable.";
			dilEnforce!DilGetException(type == Type.callable,msg);
			return callable;
		}
		else static if(is(T == DilProperty))
		{
			enum msg = "Does not contain a property.";
			dilEnforce!DilGetException(type == Type.prop,msg);
			return prop;
		}
		else static if(is(T == IDilRng))
		{
			enum msg = "Does not contain a range.";
			dilEnforce!DilGetException(type == Type.rng, msg);
			return rng;
		}
		else static if(is(T == typeof(null)))
		{
			enum msg = "Does not contain null.";
			dilEnforce!DilGetException(type == Type.prop,msg);
			return null;
		}
		else static if(is(T == Object))
		{
			enum msg = "Does not contain user object.";
			dilEnforce!DilGetException(type == Type.userObject,msg);
			return userObject;
		}
		else
			static assert(0,"'"~T.stringof~"' is not a valid get option.");
	}

	//No casts will loose information. *Except casting to ulong.
	T opCast(T)()
	if(is(T == bool))
	{
		enum msg = "Does not contain a bool.";
		if(type == Type.prop)
			return cast(T)prop.getter.call();
		dilEnforce!DilCastException(type == Type.bool_,msg);
		return b;
	}

	T opCast(T)()
	if(isIntegral!T)
	{
		enum msg = "Does not contain an int.";
		if(type == Type.prop)
			return cast(T)prop.getter.call();
		else if(type == Type.char_)
			return cast(T)c;
		dilEnforce!DilCastException(type == Type.int_,msg);
		return cast(T) i;
	}

	T opCast(T)()
	if(isFloatingPoint!T)
	{
		if(type == Type.real_)
			return cast(T) r;
		else
			return cast(T) cast(ptrdiff_t) this;
	}

	T opCast(T)()
	if(is(T == dchar))
	{
		if(type == Type.int_)
			return cast(T) i;
		else if(type == Type.string_)
		{
			dilEnforce!DilException(str.length == 1, "Can only convert to char if string is length 1.");
			return str[0];
		}
		else
			return c;
	}

	T opCast(T)() @trusted
	if(isSomeString!T)
	{
		import std.conv;

		final switch(type)
		{
			case Type.void_:
			throw new DilCastException("Cannot cast(string) void.");
			case Type.bool_:
			return b.to!T;
			case Type.int_:
			return i.to!T;
			case Type.real_:
			return r.to!T;
			case Type.char_:
			return (""d~c).to!T;
			case Type.string_:
			return str.to!T;
			case Type.array:
			return arr.to!T;
			case Type.table:
			return tbl.toString.to!T;
			case Type.inst:
			return inst.toString.to!T;
			case Type.class_:
			return clss.toString.to!T;
			case Type.callable:
			return (cast(void*)callable).to!T;
			case Type.prop:
			return prop.getter.call().toString.to!T;
			case Type.rng:
			return rng.toString.to!T;
			case Type.userObject:
			return userObject.toString.to!T;
			case Type.null_:
			return "null";
		}
	}

	size_t toHash()() nothrow @trusted const
	{
		import core.internal.hash;
		final switch(type)
		{
			case Type.void_:
			return size_t.max;
			case Type.bool_:
			return b.hashOf;
			case Type.int_:
			return i.hashOf;
			case Type.real_:
			return r.hashOf;
			case Type.char_:
			return c.hashOf;
			case Type.string_:
			return str.hashOf;
			case Type.array:
			return arr.hashOf;
			case Type.table:
			return tbl.hashOf;
			case Type.inst:
			return inst.toHash;
			case Type.class_:
			return clss.hashOf;
			case Type.callable:
			return callable.hashOf;
			case Type.prop:
			return prop.toHash;
			case Type.rng:
			return prop.hashOf;
			case Type.userObject:
			return (cast(Object) userObject).toHash;
			case Type.null_:
			return null.hashOf;
		}
	}

	real opCmp()(DilVal rhs) @trusted
	{
		enum msgArr = "Cannot compare arrays.";
		enum msgTbl = "Cannot compare tables.";
		enum msgClss = "Cannot compare class definitions.";
		enum msgCallable = "Cannot compare functions.";
		enum msgRng = "Cannot compare ranges.";
		enum msgNul = "Cannot compare null.";

		final switch(type)
		{
			case Type.void_:
			return real.nan;
			case Type.bool_:
			return b ? (cast(bool)rhs ? 0 : 1) : (cast(bool)rhs ? -1 : 0);
			case Type.int_:
			case Type.real_:
			return cast(real)this - cast(real)rhs;
			case Type.char_:
			return c - rhs.get!dchar;
			case Type.string_:
			import std.algorithm : cmp;
			return str.cmp(cast(dstring)rhs);
			case Type.array:
			throw new DilUnsupportedOpException(msgArr);
			case Type.table:
			throw new DilUnsupportedOpException(msgTbl);
			case Type.inst:
			return inst.opCmp(rhs);
			case Type.class_:
			throw new DilUnsupportedOpException(msgClss);
			case Type.callable:
			throw new DilUnsupportedOpException(msgCallable);
			case Type.prop:
			return prop.getter.call().opCmp(rhs);
			case Type.rng:
			throw new DilUnsupportedOpException(msgRng);
			case Type.userObject:
			return cast(real) userObject.opCmp(rhs.get!Object);
			case Type.null_:
			throw new DilUnsupportedOpException(msgNul);
		}
	}

	DilVal opBinary(string op)(auto ref DilVal v) @trusted
	{
		enum msgClss = "Class does not support op '"~op~"'.";
		enum msgCallable = "Callable does not support op '"~op~"'.";
		enum msgNul = "Null does not support op '"~op~"'.";
		enum msgRng = "Range does not support op '"~op~"'.";
		enum msgUserObj = "User objects do not support op '"~op~"'.";
		final switch(type)
		{
			case Type.void_:
			return DilVal.init;
			case Type.bool_:
			return b.opBinary!op(v);
			case Type.int_:
			return i.opBinary!op(v);
			case Type.real_:
			return r.opBinary!op(v);
			case Type.char_:
			return c.opBinary!op(v);
			case Type.string_:
			return str.opBinary!op(v);
			case Type.array:
			return arr.opBinary!op(v);
			case Type.table:
			return tbl.opBinary!op(v);
			case Type.inst:
			return inst.opBinary!op(v);
			case Type.class_:
			return clss.opBinary!op(v);
			case Type.callable:
			throw new DilGetException(msgCallable);
			case Type.prop:
			return prop.getter.call().opBinary!op(v);
			case Type.rng:
			throw new DilGetException(msgRng);
			case Type.userObject:
			throw new DilGetException(msgUserObj);
			case Type.null_:
			throw new DilUnsupportedOpException(msgNul);
		}
	}

	DilVal opUnary(string op)() @trusted
	{
		switch(type)
		{
			case Type.void_:
			return DilVal.init;
			static if(op == "!")
			{
				case Type.bool_:
				mixin(`return DilVal(`~op~`b);`);
			}
			case Type.int_:
			mixin(`return DilVal(`~op~`i);`);
			static if(op == "-" || op == "+")
			{
				case Type.real_:
				mixin(`return DilVal(`~op~`r);`);
			}
			case Type.char_:
			mixin(`return DilVal(`~op~`cast(ptrdiff_t)c);`);
			case Type.inst:
			return inst.opUnary!op;
			case Type.prop:
			return prop.getter.call().opUnary!op();
			default:
			throw new DilUnsupportedOpException("Does not support unary op.");
		}
	}

	DilVal opIndex()(DilVal v) @trusted
	{
		if(type == Type.array)
		{
			if(v.type == Type.real_)
			{
				real ndx = v.get!real;
				import std.math : trunc, isFinite;
				dilEnforce!DilCastException(ndx.isFinite && ndx.trunc == ndx,"Real must be whole number when indexing array.");
				return arr[cast(ptrdiff_t)ndx];
			}
			else
				return arr[cast(ptrdiff_t)v];
		}
		else if(type == Type.table)
			return tbl[v];
		else if(type == Type.inst)
			return inst[v];
		else if(type == Type.class_)
			return DilVal(clss.ctors[v.get!dstring]);
		else if(type == Type.prop)
			return prop.getter.call()[v];
		else
			throw new DilCastException("Does not support indexing on this type.");	
	}

	DilVal opBinary(string op,T)(auto ref T v) @trusted
	{
		return this.opBinary!op(DilVal(v));
	}

	string toString() @safe
	{
		return cast(string)this;
	}

	size_t length() @trusted
	{
		if(type == Type.array)
		{
			return arr.length;
		}
		else if(type == Type.table)
			return tbl.length;
		else if(type == Type.inst)
			return inst.length;
		else if(type == Type.prop)
			return prop.getter.call().length;
		else
			throw new DilCastException("Does not support length on this type.");	
	}
}

struct DilKey
{
	DilVal val;

	size_t toHash() nothrow @safe const
	{
		return val.toHash();
	}

	//strict equals / wont throw on mismatch type
	bool opEquals()(auto ref const(DilKey) rhs) @trusted const
	{
		import std.traits : EnumMembers;
		final switch(val.type)
		{
			case DilVal.Type.void_:
			return rhs.val.type == DilVal.Type.void_;
			static foreach(i,e; EnumMembers!(DilVal.Type)[1..$])
			{
				case e:
				return rhs.val.type == e && val.get!(DilVal.ImplTypes[i]) == rhs.val.get!(DilVal.ImplTypes[i]);
			}
		}
	}

	string toString()()
	{
		return val.toString;
	}
}

final class DilUnsupportedOpException : DilException
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

final class DilGetException : DilException
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

final class DilCastException : DilException
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

final class DilRangeException : DilException
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

@safe:
DilVal opBinary(string op)(bool l, DilVal r)
{
	static if(op == "|" || op == "&")
	{
		mixin("return DilVal(l "~op~" cast(bool)r);");
	}
	else
	{
		enum msg = "bool does not support '"~op~"'.";
		throw new DilUnsupportedOpException(msg);
	}
}

DilVal opBinary(string op)(ptrdiff_t l, DilVal r)
{
	static if(op == "~" || op == "in")
	{
		enum msg = "int does not support '"~op~"'.";
		throw new DilUnsupportedOpException(msg);
	}
	else
	{
		static if(op == "+" || op == "-" || op == "*" || op == "/" || op == "%" || op == "^^")
		{
			if(r.type == DilVal.Type.real_)
				mixin(`return DilVal(l `~op~` r.get!real);`);
		}

		mixin(`return DilVal(l `~op~` cast(ptrdiff_t)r);`);
	}
}

DilVal opBinary(string op)(real l, DilVal r)
{
	static if(op == "~" || op == "in" || op == "&" || op == "|" || op == "^" || op == "<<" || op == ">>" || op == ">>>")
	{
		enum msg = "real does not support '"~op~"'.";
		throw new DilUnsupportedOpException(msg);
	}
	else
	{
		mixin(`return DilVal(l `~op~` cast(real)r);`);
	}
}

DilVal opBinary(string op)(dchar l, DilVal r)
{
	static if(op == "~")
	{
		return DilVal(""d ~ l ~ cast(dstring)r);
	}
	else static if(op == "in")
	{
		enum msg = "char does not support '"~op~"'.";
		throw new DilUnsupportedOpException(msg);
	}
	else
	{
		mixin(`return DilVal(l `~op~` cast(ptrdiff_t)r);`);
	}
}

DilVal opBinary(string op,T)(T l, DilVal r)
if(isSomeString!T)
{
	static if(op == "~")
	{
		return DilVal(l ~ cast(dstring)r);
	}
	else
	{
		enum msg = "string does not support '"~op~"'.";
		throw new DilUnsupportedOpException(msg);
	}
}

DilVal opBinary(string op)(DilVal[] l, DilVal r)
{
	static if(op == "~")
	{
		return DilVal(l ~ r.get!(DilVal[]));
	}
	else
	{
		enum msg = "array does not support '"~op~"'.";
		throw new DilUnsupportedOpException(msg);
	}
}

DilVal opBinary(string op)(DilTable l, DilVal r)
{
	enum msg = "table does not support '"~op~"'.";
	throw new DilUnsupportedOpException(msg);
}