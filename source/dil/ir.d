module dil.ir;

import dil.exception;
import dil.val;
import dil.rng;
import dil.lib;

final class DilRawFunc
{
	Instruction[] instrs;
	dstring[] argNames;
	dstring varargName;
	string file;

	this()(Instruction[] instrs, dstring[] argNames, dstring varargName, string file = __FILE__)
	{
		this.instrs = instrs;
		this.argNames = argNames;
		this.varargName = varargName;
		this.file = file;
	}

	override string toString()
	{
		import std.format : format;
		import std.algorithm : map;
		return format!"%s"(instrs.map!(v => v.action));
	}

	DilVal call(DilTable context, DilVal[] args...) const @trusted
	{
		DilTable dilScope = new DilTable(context);
		dilScope.vals[DilKey(DilVal("this"))] = DilVal(context);

		dilEnforce!DilArgException(args.length >= argNames.length,"Not enough arguments.",file,instrs[0].line);

		foreach(i,ref v; args[0..argNames.length])
		{
			dilScope.vals[DilKey(DilVal(argNames[i]))] = v;
		}

		if(varargName !is null)
			dilScope.vals[DilKey(DilVal(varargName))] = DilVal(args[argNames.length..$]);

		for(size_t pos = 0;; pos++)
		{
			try
			{
				assert(pos < instrs.length);
				import std.conv : text;
				final switch(instrs[pos].action)
				{
					case Instruction.Action.assign:
					instrs[pos].lhs.evalAsLVal(dilScope).set(instrs[pos].rhs.eval(dilScope));
					break;
					case Instruction.Action.localDecl:
					dilScope.update(DilVal(instrs[pos].ident),
					delegate()
					{
						return instrs[pos].initializer.eval(dilScope);
					},
					delegate DilVal(ref DilVal existing) @safe
					{
						throw new DilDeclException("Local var '" ~ instrs[pos].ident.text ~ "' already exists.",file,instrs[pos].line);
					});
					break;
					case Instruction.Action.globalDecl:
					dilTLSScope.update(DilVal(instrs[pos].ident),
					delegate()
					{
						return instrs[pos].initializer.eval(dilScope);
					},
					delegate DilVal(ref DilVal existing)
					{
						throw new DilDeclException("Global var '" ~ instrs[pos].ident.text ~ "' already exists.",file,instrs[pos].line);
					});
					break;
					case Instruction.Action.expr:
					instrs[pos].rhs.eval(dilScope);
					break;
					case Instruction.Action.go:
					if(instrs[pos].cond is null || instrs[pos].cond.eval(dilScope))
						pos += instrs[pos].displacement;
					break;
					case Instruction.Action.newScope:
					dilScope = new DilTable(dilScope);
					break;
					case Instruction.Action.delScope:
					dilScope = dilScope.parentScope;
					assert(dilScope !is null);
					break;
					case Instruction.Action.ret:
					if(instrs[pos].rhs is null)
						return DilVal.init;
					else
						return instrs[pos].rhs.eval(dilScope);
					case Instruction.Action.rngPopFront:
					instrs[pos].rng.eval(dilScope).get!IDilRng.advance;
					break;
				}
			}
			catch(Throwable e)
			{
				e.file = file;
				e.line = instrs[pos].line;
				throw e;
			}
		}

		assert(0);
	}
}

final class DilArgException : DilException
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

final class DilDeclException : DilException
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

final class DilFunc : IDilCallable
{
	const DilRawFunc fnc;
	DilTable _context;
	this()(auto ref const DilRawFunc fnc, DilTable _context = null)
	in(fnc !is null)
	{
		this.fnc = fnc;
		this._context = _context;
	}

	IDilCallable context(DilVal val)
	{
		return new DilFunc(fnc,val.get!DilTable);
	}

	DilVal call(DilVal[] args...)
	{
		return fnc.call(_context,args);
	}

	size_t toHash() inout @trusted
	{
		return cast(size_t)cast(void*)this;
	}
}

struct Instruction
{
	enum Action
	{
		assign,
		localDecl,
		globalDecl,
		expr,
		go,
		newScope,
		delScope,
		ret,
		rngPopFront
	}

	Action action;

	union
	{
		struct
		{
			const(IExpression) _lhs;
			const(IExpression) _rhs;
		}

		struct
		{
			const(IExpression) _cond;
			ptrdiff_t _displacement;
		}

		struct
		{
			dstring _ident;
			const(IExpression) _initializer;
		}

		struct
		{
			const(IExpression) _rng;
		}
	}

	size_t line;

	pure nothrow @nogc @trusted:

	const(IExpression) lhs() const @property
	{
		return _lhs;
	}

	const(IExpression) rhs() const @property
	{
		return _rhs;
	}

	const(IExpression) cond() const @property
	{
		return _cond;
	}

	ptrdiff_t displacement() const @property
	{
		return _displacement;
	}

	dstring ident() const @property
	{
		return _ident;
	}

	const(IExpression) initializer() const @property
	{
		return _initializer;
	}

	const(IExpression) rng() const @property
	{
		return _rng;
	}

	this(Action _action, const(IExpression) _lhs, const(IExpression) _rhs, size_t _line = __LINE__)
	{
		this.action = _action;
		this._lhs = _lhs;
		this._rhs = _rhs;
		this.line = _line;
	}

	this(Action _action, const(IExpression) _cond, ptrdiff_t _displacement, size_t _line = __LINE__)
	{
		this.action = _action;
		this._cond = _cond;
		this._displacement = _displacement;
		this.line = _line;
	}

	this(Action _action, dstring _ident, const(IExpression) _initializer, size_t _line = __LINE__)
	{
		this.action = _action;
		this._ident = _ident;
		this._initializer = _initializer;
		this.line = _line;
	}

	this(Action _action, const(IExpression) _rng, size_t _line = __LINE__)
	{
		this.action = _action;
		this._rng = _rng;
		this.line = _line;
	}

	this(Action _action, size_t _line = __LINE__)
	{
		this.action = _action;
		this.line = _line;
	}

	static:
	Instruction assign(const IExpression lhs,const IExpression rhs, size_t line = __LINE__)
	in(lhs !is null)
	in(rhs !is null)
	{
		return Instruction(Action.assign,lhs,rhs,line);
	}

	Instruction localDecl(dstring ident,const IExpression initializer, size_t line = __LINE__)
	in(ident !is null)
	in(initializer !is null)
	{
		return Instruction(Action.localDecl,ident,initializer,line);
	}

	Instruction globalDecl(dstring ident,const IExpression initializer, size_t line = __LINE__)
	in(ident !is null)
	in(initializer !is null)
	{
		return Instruction(Action.globalDecl,ident,initializer,line);
	}

	Instruction expr(const IExpression expression, size_t line = __LINE__)
	in(expression !is null)
	{
		return Instruction(Action.expr,cast(const(IExpression))null,expression,line);
	}

	Instruction go(const IExpression cond, ptrdiff_t displacement, size_t line = __LINE__)
	{
		return Instruction(Action.go,cond,displacement,line);
	}

	Instruction newScope(size_t line = __LINE__)
	{
		return Instruction(Action.newScope,line);
	}

	Instruction delScope(size_t line = __LINE__)
	{
		return Instruction(Action.delScope,line);
	}

	Instruction ret(const IExpression expression, size_t line = __LINE__)
	{
		return Instruction(Action.ret,cast(const(IExpression))null,expression,line);
	}

	Instruction rngPopFront(const IExpression rng, size_t line = __LINE__)
	{
		return Instruction(Action.rngPopFront,rng,line);
	}
}

interface IExpression
{
	@safe:
	final const(IExpression) simplify() const
	{
		import dil.irexpr : ValueExpr, DilCTEvalException;
		try
		{
			return new ValueExpr(ctEval());
		}
		catch(DilCTEvalException e)
		{
			return this;
		}
	}
	DilVal ctEval() const;

	DilLVal evalAsLVal(DilTable dilScope) const;
	DilVal eval(DilTable dilScope) const;
}

struct DilLVal
{
	DilVal val;
	DilVal idx;

	DilVal get()() @safe
	{
		if(idx.type != DilVal.Type.void_)
			return val[idx];
		else
			return val;
	}

	void set()(auto ref DilVal v)
	{
		if(idx.type != DilVal.Type.void_)
		{
			if(val.type == DilVal.Type.table)
				val.get!DilTable[idx] = v;
			else if(val.type == DilVal.Type.array)
				val.get!(DilVal[])[idx.get!ptrdiff_t] = v;
			else if(val.type == DilVal.Type.inst)
				val.get!DilInst[idx] = v;
			else
				val.get!DilProperty.setter.call(v);
		}
		else
			val = v;
	}
}