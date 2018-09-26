module dil.meta;

import std.traits : isCallable, Parameters, ReturnType, Unqual,TemplateOf;
import std.meta;

import dil.val;
import dil.exception;

template UnqualSeq(SEQ...)
{
	static if(SEQ.length == 0)
	{
		alias UnqualSeq = AliasSeq!();
	}
	else
	{
		alias UnqualSeq = AliasSeq!(Unqual!(SEQ[0]),UnqualSeq!(AliasSeq!(SEQ[1..$])));
	}
}

IDilCallable makeDilCallable(T)(T fnc, string nm = null)
if(isCallable!T)
{
	import std.format : format;
	enum nullMsg = format!"Expecting %s args. There are %%s."(Parameters!T.length);
	enum nmMsg = format!"Expecting %s arg%s in '%%s'. There are %%%%s."(Parameters!T.length,Parameters!T.length == 1 ? "s" : "");

	immutable msg = (nm is null) ? nullMsg : format!nmMsg(nm);

	return new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted
	{	
		dilEnforce!DilException(args.length == Parameters!T.length, format(msg,args.length));

		import std.typecons : Tuple;
		Tuple!(UnqualSeq!(Parameters!T)) realArgs;
		static foreach(n,A; UnqualSeq!(Parameters!T))
		{
			static if(is(A == DilVal))
			{
				realArgs[n] = args[n];
			}
			else static if(__traits(compiles,cast(A) args[n]))
			{
				realArgs[n] = cast(A) args[n];
			}
			else static if(__traits(compiles,args[n].get!A))
			{
				realArgs[n] = args[n].get!A;
			}
			else static if(is(A == interface))
			{{
				enum msg = "Must be a native D object to convert to a '"~A.stringof~"'.";
				DilInst inst = args[n].get!DilInst;
				dilEnforce!DilException(inst.instData.shallowContains("nativeObject"d),msg);

				Object tmp = inst.instData["nativeObject"d].get!DilProperty.getter.call().get!Object;
				assert(tmp !is null,"tmp is null.");

				realArgs[n] = cast(A) tmp;
				assert(realArgs[n] !is null,"null after cast.");
			}}
			else
				static assert(0,A.stringof ~ " is not supported.");
		}

		static if(is(ReturnType!T == void))
		{
			fnc(realArgs.expand);
			return DilVal.init;
		}
		else static if(is(ReturnType!T : IDilContextlessConstructable))
		{
			return DilVal(fnc(realArgs.expand).toDilInstance);
		}
		else
		{
			return DilVal(fnc(realArgs.expand));
		}
	});
}

interface IDilContextlessConstructable
{
	DilInst toDilInstance() @safe;
}

DilInst constructNativeInst(I)(I val, IDilClass clss)
in(val !is null)
{
	import std.traits;
	Object objVal = cast(Object) val;

	DilTable tbl = new DilTable;

	if(objVal !is null)
		tbl[DilVal("nativeObject"d)] = DilVal(DilProperty(new DilDDelegate(delegate DilVal(DilTable context,DilVal[] args...){ return DilVal(objVal); },null),null));

	static foreach(nm; __traits(allMembers,I))
	{{
		import std.conv : dtext;
		enum nmd = nm.dtext;
		static if(hasFunctionAttributes!(__traits(getMember,I,nm),"@property"))
		{
			DilProperty prop;

			foreach(n,overload; __traits(getOverloads,I,nm))
			{
				
				static if(Parameters!(FunctionTypeOf!overload).length == 0 && !is(ReturnType!(FunctionTypeOf!overload) == void))
				{
					prop.getter = makeDilCallable(&__traits(getOverloads,val,nm)[n]);
				}
				else static if(Parameters!(FunctionTypeOf!overload).length == 1 && is(ReturnType!(FunctionTypeOf!overload) == void))
				{
					prop.setter = makeDilCallable(&__traits(getOverloads,val,nm)[n]);
				}
			}
			tbl[DilVal(nmd)] = DilVal(prop);
		}
		else
		{
			static assert(__traits(getOverloads,val,nm).length == 1,"Except for properties, all functions should have one overload to be a native dil class.");
			tbl[DilVal(nmd)] = DilVal(makeDilCallable(&__traits(getOverloads,val,nm)[0]));
		}
	}}

	return DilInst(tbl,clss);
}

final class NativeDilClass(I) : IDilClass
{
	IDilCallable[dstring] _ctors;

	void constructData(DilTable tbl)
	{
		throw new DilException("Native classes cannot be inherited from.");
	}

	DilInst constructInstance()
	{
		throw new DilException("Native classes cannot be inherited from.");
	}

	DilVal appendParent(DilVal v)
	{
		throw new DilException("Native classes cannot have parents.");
	}

	IDilCallable[dstring] ctors() { return _ctors; }

	void addCtor( dstring name, I delegate(DilVal[] args...) @safe ctor ) @safe
	{
		IDilClass tmp = this;
		final class NativeDilCtor : IDilCallable
		{
			IDilCallable context(DilVal val)
			{
				return this;
			}

			DilVal call(DilVal[] args...) @trusted
			{
				I val = ctor(args);
				return DilVal(constructNativeInst!I(val,tmp));
			}

			size_t toHash() inout @trusted
			{
				return cast(size_t)cast(void*)this;
			}
		}

		_ctors[name] = new NativeDilCtor;
	}

	override string toString() pure nothrow @safe @nogc { enum nm = "Native Class: "~I.stringof; return nm; }
}