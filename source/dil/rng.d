module dil.rng;

import dil.val : DilVal, DilTable, DilInst, IDilCallable, DilProperty, DilKey;
import dil.exception;

interface IDilRng
{
	DilVal value() @safe @property;
	DilVal key() @safe @property;
	bool isEmpty() @safe @property;
	void advance() @safe;

	final string toString() @safe
	{
		if(isEmpty())
			return "[]";
		string str = "[";
		str ~= '\'';
		str ~= value().toString;
		str ~= '\'';
		advance();
		for(;!isEmpty();advance())
		{
			str ~= ",'";
			str ~= value().toString;
			str ~= '\'';
		}
		str ~= ']';
		return str;
	}
}

interface IDilRangeUserObjFactory
{
	IDilRng createRange();
}

IDilRng makeDilRng()(auto ref DilVal val) @safe
{
	final switch(val.type)
	{
		case DilVal.Type.void_:
			throw new DilRangeException("Cannot make a dil range out of 'void'.");
		case DilVal.Type.bool_:
			throw new DilRangeException("Cannot make a dil range out of 'bool'.");
		case DilVal.Type.int_:
			throw new DilRangeException("Cannot make a dil range out of 'int'.");
		case DilVal.Type.real_:
			throw new DilRangeException("Cannot make a dil range out of 'real'.");
		case DilVal.Type.char_:
			throw new DilRangeException("Cannot make a dil range out of 'char'.");
		case DilVal.Type.string_:
			return new DilStrRng(val.get!dstring);
		case DilVal.Type.array:
			return new DilArrRng(val.get!(DilVal[]));
		case DilVal.Type.table:
			return new DilTblRng(val.get!(DilTable));
		case DilVal.Type.inst:
			return new DilInstRng(val.get!(DilInst));
		case DilVal.Type.class_:
			throw new DilRangeException("Cannot make a dil range out of 'class'.");
		case DilVal.Type.callable:
			return new DilCallableRng(val.get!IDilCallable);
		case DilVal.Type.prop:
			return val.get!DilProperty().getter.call().makeDilRng;
		case DilVal.Type.rng:
			return val.get!IDilRng;
		case DilVal.Type.userObject:
		return delegate() @trusted {
			auto factory = cast(IDilRangeUserObjFactory) val.get!Object;
			if(factory is null)
				throw new DilRangeException("Cannot make a dil range out of user object that doesn't implement IDilRangeUserObjFactory.");
			return factory.createRange();
		}();
		case DilVal.Type.null_:
			throw new DilRangeException("Cannot make a dil range out of 'null'.");
	}
}

final class DilRangeException : DilException
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

private:
final class DilStrRng : IDilRng
{
	dstring s;
	ptrdiff_t loc;

	this()(dstring s)
	{
		this.s = s;
	}

	DilVal value() @safe @property
	{
		return DilVal(s[loc]);
	}
	DilVal key() @safe @property
	{
		return DilVal(loc);
	}
	bool isEmpty() @safe @property
	{
		return loc >= s.length;
	}
	void advance() @safe
	{
		++loc;
	}
}

final class DilArrRng : IDilRng
{
	DilVal[] arr;
	ptrdiff_t loc = 0;

	this()(DilVal[] arr)
	{
		this.arr = arr;
	}

	DilVal value() @safe @property
	{
		return arr[loc];
	}
	DilVal key() @safe @property
	{
		return DilVal(loc);
	}
	bool isEmpty() @safe @property
	{
		return loc >= arr.length;
	}
	void advance() @safe
	{
		++loc;
	}
}

final class DilTblRng : IDilRng
{
	ptrdiff_t loc = 0;
	DilTable tbl;
	DilKey[] ks;
	this()(DilTable tbl)
	{
		this.tbl = tbl;
		this.ks = tbl.keys;
	}

	DilVal value() @safe @property
	{
		return tbl[ks[loc].val];
	}
	DilVal key() @safe @property
	{
		return ks[loc].val;
	}
	bool isEmpty() @safe @property
	{
		return loc >= ks.length;
	}
	void advance() @safe
	{
		++loc;
	}
}

final class DilInstRng : IDilRng
{
	DilInst inst;

	this()(DilInst inst)
	{
		this.inst = inst;
	}

	DilVal value() @safe @property
	{
		DilVal v = inst.instData["value"];
		if(v.type == DilVal.Type.callable)
			return v.get!IDilCallable().call();
		else if(v.type == DilVal.Type.prop)
			return v.get!DilProperty().getter.call();
		else
			return v;
	}
	DilVal key() @safe @property
	{
		DilVal v = inst.instData["key"];
		if(v.type == DilVal.Type.callable)
			return v.get!IDilCallable().call();
		else if(v.type == DilVal.Type.prop)
			return v.get!DilProperty().getter.call();
		else
			return v;
	}
	bool isEmpty() @safe @property
	{
		DilVal v = inst.instData["isEmpty"];
		if(v.type == DilVal.Type.callable)
			return cast(bool)v.get!IDilCallable().call();
		else if(v.type == DilVal.Type.prop)
			return cast(bool)v.get!DilProperty().getter.call();
		else
			return cast(bool)v;
	}
	void advance() @safe
	{
		DilVal v = inst.instData["advance"];
		if(v.type == DilVal.Type.callable)
			v.get!IDilCallable().call();
		else
			throw new DilRangeException("advance must be a function in ranges.");
	}
}

final class DilCallableRng : IDilRng
{
	IDilCallable cllbl;
	DilVal v;
	ptrdiff_t k = 0;

	this()(IDilCallable cllbl)
	{
		this.cllbl = cllbl;
		this.v = cllbl.call(DilVal(k));
	}

	DilVal value() @safe @property
	{
		return v;
	}
	DilVal key() @safe @property
	{
		return DilVal(k);
	}
	bool isEmpty() @safe @property
	{
		return v.type == DilVal.Type.void_;
	}
	void advance() @safe
	{
		v = cllbl.call(DilVal(++k));
	}
}