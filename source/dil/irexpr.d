module dil.irexpr;

import dil.exception;
import dil.ir;
import dil.val;
import dil.rng;
import dil.lib;

final class DilCTEvalException : DilException
{
	this()(string file = __FILE__, size_t line = __LINE__)
	{
		super("Cannot be simplified.",file,line);
	}
}

final class ValueExpr : IExpression
{
	DilVal val;

	this()(DilVal v)
	{
		val = v;
	}

	this(T)(T v)
	if(!is(T == DilVal))
	{
		val = DilVal(v);
	}

	DilVal ctEval() const
	{
		return eval(null);
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(val,DilVal.init);
	}

	DilVal eval(DilTable dilScope) const @trusted
	{
		return *cast(DilVal*)&val;
	}
}

final class FuncExpr : IExpression
{
	IDilCallable callable;

	this()(IDilCallable callable)
	{
		this.callable = callable;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const @trusted
	{
		return DilVal((cast(IDilCallable)callable).context(DilVal(dilScope)));
	}
}

final class BinaryExpr(string op) : IExpression
{
	const IExpression lhs;
	const IExpression rhs;

	this()(const IExpression lhs,const IExpression rhs)
	{
		this.lhs = lhs.simplify;
		this.rhs = rhs.simplify;
	}

	DilVal ctEval() const
	{
		mixin(`return lhs.ctEval() `~op~` rhs.ctEval();`);
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		mixin(`return lhs.eval(dilScope) `~op~` rhs.eval(dilScope);`);
	}
}

final class CmpExpr(string op) : IExpression
{
	const IExpression lhs;
	const IExpression rhs;

	this()(const IExpression lhs,const IExpression rhs)
	{
		this.lhs = lhs.simplify;
		this.rhs = rhs.simplify;
	}

	DilVal ctEval() const
	{
		mixin(`return DilVal(lhs.ctEval() `~op~`(rhs.ctEval()));`);
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		mixin(`return DilVal(lhs.eval(dilScope) `~op~` rhs.eval(dilScope));`);
	}
}

final class MemberAccessExpr : IExpression
{
	const IExpression inner;
	dstring member;
	this()(const IExpression inner, dstring member)
	{
		this.inner = inner.simplify;
		this.member = member;
	}

	DilVal ctEval() const
	{
		return inner.ctEval[DilVal(member)];
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(inner.eval(dilScope),DilVal(member));
	}

	DilVal eval(DilTable dilScope) const
	{
		return inner.eval(dilScope)[DilVal(member)];
	}
}

final class IndexAccessExpr : IExpression
{
	const IExpression inner;
	const IExpression member;
	this()(const IExpression inner, const IExpression member)
	{
		this.inner = inner.simplify;
		this.member = member;
	}

	DilVal ctEval() const
	{
		return inner.ctEval[member.ctEval];
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(inner.eval(dilScope),member.eval(dilScope));
	}

	DilVal eval(DilTable dilScope) const
	{
		return inner.eval(dilScope)[member.eval(dilScope)];
	}
}

final class PrefixExpr(string op) : IExpression
{
	const IExpression inner;

	this()(const IExpression inner)
	{
		this.inner = inner.simplify;
	}

	DilVal ctEval() const
	{
		return inner.ctEval().opUnary!op;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return inner.eval(dilScope).opUnary!op;
	}
}

final class DollarExpr : IExpression
{
	const IExpression inner;

	this()(const IExpression inner)
	{
		this.inner = inner.simplify;
	}

	DilVal ctEval() const
	{
		return DilVal(inner.ctEval.length);
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(DilVal(inner.eval(dilScope).length),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return DilVal(inner.eval(dilScope).length);
	}
}

final class PreIncrExpr : IExpression
{
	const IExpression inner;

	this()(const IExpression inner)
	{
		this.inner = inner.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		DilLVal tmp = inner.evalAsLVal(dilScope);
		tmp.set(tmp.get()+1); 
		return tmp;
	}

	DilVal eval(DilTable dilScope) const
	{
		return evalAsLVal(dilScope).get();
	}
}

final class PreDecrExpr : IExpression
{
	const IExpression inner;

	this()(const IExpression inner)
	{
		this.inner = inner.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		DilLVal tmp = inner.evalAsLVal(dilScope);
		tmp.set(tmp.get()-1); 
		return tmp;
	}

	DilVal eval(DilTable dilScope) const
	{
		return evalAsLVal(dilScope).get();
	}
}

final class PostIncrExpr : IExpression
{
	const IExpression inner;

	this()(const IExpression inner)
	{
		this.inner = inner.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		DilLVal tmp = inner.evalAsLVal(dilScope);
		DilVal ret = tmp.get;
		tmp.set(ret+1); 
		return ret;
	}
}

final class PostDecrExpr : IExpression
{
	const IExpression inner;

	this()(const IExpression inner)
	{
		this.inner = inner.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		DilLVal tmp = inner.evalAsLVal(dilScope);
		DilVal ret = tmp.get;
		tmp.set(ret-1); 
		return ret;
	}
}

final class CallExpr : IExpression
{
	const IExpression inner;
	const(IExpression)[] args;

	import std.algorithm : map;
	import std.array : array;

	this()(const IExpression inner, const(IExpression)[] args...)
	{
		this.inner = inner.simplify;
		this.args = args.map!(a => a.simplify).array;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return inner.eval(dilScope).get!IDilCallable.call(args.map!(a => a.eval(dilScope)).array);
	}
}

final class FwdVarArgCallExpr : IExpression
{
	const IExpression inner;
	const(IExpression)[] args;
	const IExpression vararg;

	import std.algorithm : map;
	import std.array : array;

	this()(const IExpression inner, const(IExpression)[] args, const(IExpression) vararg)
	{
		this.inner = inner.simplify;
		this.args = args.map!(a => a.simplify).array;
		this.vararg = vararg.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return inner.eval(dilScope).get!IDilCallable.call(args.map!(a => a.eval(dilScope)).array ~ vararg.eval(dilScope).get!(DilVal[]));
	}
}

final class ArrCtorExpr : IExpression
{
	const(IExpression)[] args;

	import std.algorithm : map;
	import std.array : array;

	this()(const(IExpression)[] args)
	{
		this.args = args.map!(a => a.simplify).array;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
		//return args.map!(a => a.ctEval).array;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return DilVal(args.map!(a => a.eval(dilScope)).array);
	}
}

final class TblCtorExpr : IExpression
{
	const(IExpression)[] keys;
	const(IExpression)[] values;


	import std.algorithm : map;
	import std.array : array;

	this()(const(IExpression)[] keys, const(IExpression)[] values)
	{
		this.keys = keys.map!(a => a.simplify).array;
		this.values = values.map!(a => a.simplify).array;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
		//return args.map!(a => a.ctEval).array;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		DilTable tbl = new DilTable;
		foreach(n; 0..keys.length)
			tbl[keys[n].eval(dilScope)] = values[n].eval(dilScope);
		return DilVal(tbl);
	}
}

final class TernaryExpr : IExpression
{
	const IExpression cond;
	const IExpression t;
	const IExpression f;

	this()(const IExpression cond, const IExpression t, const IExpression f)
	{
		this.cond = cond.simplify;
		this.t = t.simplify;
		this.f = f.simplify;
	}

	DilVal ctEval() const
	{
		return cond.ctEval ? t.ctEval : f.ctEval;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return cond.eval(dilScope) ? t.evalAsLVal(dilScope) : f.evalAsLVal(dilScope);
	}

	DilVal eval(DilTable dilScope) const
	{
		return cond.eval(dilScope) ? t.eval(dilScope) : f.eval(dilScope);
	}
}

final class LocalAccessExpr : IExpression
{
	dstring ident;

	this()(dstring ident)
	{
		this.ident = ident;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(DilVal(dilScope),DilVal(ident));
	}

	DilVal eval(DilTable dilScope) const
	{
		DilVal v = dilScope[DilVal(ident)];
		while(v.type == DilVal.Type.prop)
			v = v.get!DilProperty.getter.call();
		return v;
	}
}

final class GlobalAccessExpr : IExpression
{
	dstring ident;

	this()(dstring ident)
	{
		this.ident = ident;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(DilVal(dilTLSScope),DilVal(ident));
	}

	DilVal eval(DilTable dilScope) const
	{
		DilVal v = dilTLSScope[DilVal(ident)];
		while(v.type == DilVal.Type.prop)
			v = v.get!DilProperty.getter.call();
		return v;
	}
}

final class MakeRngExpr : IExpression
{
	const IExpression inner;

	this()(const IExpression inner)
	{
		this.inner = inner.simplify;
	}

	DilVal ctEval() const
	{
		//Do not try to create ranges in ctEval, since won't be recreated on each excution.
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return DilVal(inner.eval(dilScope).makeDilRng);
	}
}

final class LdKFromRngExpr : IExpression
{
	const IExpression rng;

	this()(const IExpression rng)
	{
		this.rng = rng.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return rng.eval(dilScope).get!IDilRng.key;
	}
}

final class LdVFromRngExpr : IExpression
{
	const IExpression rng;

	this()(const IExpression rng)
	{
		this.rng = rng.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return rng.eval(dilScope).get!IDilRng.value;
	}
}

final class IsEmptyRngExpr : IExpression
{
	const IExpression rng;

	this()(const IExpression rng)
	{
		this.rng = rng.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return DilVal(rng.eval(dilScope).get!IDilRng.isEmpty);
	}
}

final class OrShortCircuitExpr : IExpression
{
	const IExpression l;
	const IExpression r;
	this()(const IExpression l,const IExpression r)
	{
		this.l = l.simplify;
		this.r = r.simplify;
	}

	DilVal ctEval() const
	{
		DilVal tmp = l.ctEval;
		if(tmp)
			return tmp;
		else
			return r.ctEval;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		DilLVal tmp = l.evalAsLVal(dilScope);
		if(tmp.get)
			return tmp;
		else
			return r.evalAsLVal(dilScope);
	}

	DilVal eval(DilTable dilScope) const
	{
		DilVal tmp = l.eval(dilScope);
		if(tmp)
			return tmp;
		else
			return r.eval(dilScope);
	}
}

final class AndShortCircuitExpr : IExpression
{
	const IExpression l;
	const IExpression r;
	this()(const IExpression l,const IExpression r)
	{
		this.l = l.simplify;
		this.r = r.simplify;
	}

	DilVal ctEval() const
	{
		DilVal tmp = l.ctEval;
		if(!tmp)
			return tmp;
		else
			return r.ctEval;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		DilLVal tmp = l.evalAsLVal(dilScope);
		if(!tmp.get)
			return tmp;
		else
			return r.evalAsLVal(dilScope);
	}

	DilVal eval(DilTable dilScope) const
	{
		DilVal tmp = l.eval(dilScope);
		if(!tmp)
			return tmp;
		else
			return r.eval(dilScope);
	}
}

final class LdScopeExpr : IExpression
{
	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) const
	{
		return DilVal(dilScope);
	}
}

final class DefineClassExpr : IExpression
{
	DilRawFunc classDef;
	IDilCallable[dstring] ctors;
	this()(DilRawFunc classDef, IDilCallable[dstring] ctors)
	{
		this.classDef = classDef;
		this.ctors = ctors;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		return DilLVal(eval(dilScope),DilVal.init);
	}

	DilVal eval(DilTable dilScope) @trusted const
	{
		DilTable tbl = classDef.call(dilScope).get!DilTable;
		return DilVal(new DilClass(tbl.vals,dilScope,cast(IDilCallable[dstring])ctors));
	}
}

final class AssignExpr : IExpression
{
	const IExpression lhs;
	const IExpression rhs;

	this()(const IExpression lhs,const IExpression rhs)
	{
		this.lhs = lhs.simplify;
		this.rhs = rhs.simplify;
	}

	DilVal ctEval() const
	{
		throw new DilCTEvalException;
	}

	DilLVal evalAsLVal(DilTable dilScope) const
	{
		DilLVal r = rhs.evalAsLVal(dilScope);
		lhs.evalAsLVal(dilScope).set(r.get());
		return r;
	}

	DilVal eval(DilTable dilScope) @trusted const
	{
		DilVal r = rhs.eval(dilScope);
		lhs.evalAsLVal(dilScope).set(r);
		return r;
	}
}