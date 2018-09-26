module dil.irbuilder;

import dil.ir;
import dil.val : IDilCallable;
public import dil.ir : IExpression;

struct DilIRBuilder
{
	Instruction[] instrs;
	dstring[] args;
	dstring vararg;
	string file;
	IDilCallable[dstring] ctors;

	pure nothrow @safe:
	this(dstring[] args, dstring vararg, string file)
	{
		this.args = args;
		this.vararg = vararg;
		this.file = file;
	}

	this(string file)
	{
		this.file = file;
	}

	DilRawFunc build()
	{
		assert(entries.length == 0);
		return new DilRawFunc(instrs,args,vararg,file);
	}

	alias AbsPos = size_t;
	alias Handle = ushort;

	AbsPos[] bindings;
	AbsPos[][Handle] entries;

	Handle newHandle()
	{
		ushort tmp = cast(ushort)(bindings.length++);
		bindings[tmp] = AbsPos.max;
		return tmp;
	}

	Handle bindHandle(Handle handle) @trusted
	{
		bindings[handle] = instrs.length;

		AbsPos[]* tmp = handle in entries;

		if(tmp !is null)
		{
			foreach(pos; *tmp)
			{
				assert(instrs[pos].action == Instruction.Action.go);
				instrs[pos]._displacement = cast(ptrdiff_t)(bindings[handle] - (pos + 1));
			}

			entries.remove(handle);
		}

		return handle;
	}

	void resolve(Handle handle) @trusted
	{
		assert(instrs[$-1].action == Instruction.Action.go);

		if(bindings[handle] == AbsPos.max)
		{
			entries[handle] ~= instrs.length - 1;
		}
		else
		{
			instrs[$-1]._displacement = cast(ptrdiff_t)(bindings[handle] - instrs.length);
		}
	}

	void emit(Instruction ir)
	{
		instrs ~= ir;
	}

	void assign(const(IExpression) lhs, const(IExpression) rhs, size_t line = __LINE__)
	{
		emit(Instruction.assign(lhs,rhs,line));
	}

	void localDecl(dstring ident, const(IExpression) initializer, size_t line = __LINE__)
	{
		emit(Instruction.localDecl(ident,initializer,line));
	}

	void globalDecl(dstring ident, const(IExpression) initializer, size_t line = __LINE__)
	{
		emit(Instruction.globalDecl(ident,initializer,line));
	}

	void ctorDecl(dstring ident, IDilCallable initializer, size_t line = __LINE__)
	{
		ctors[ident] = initializer;
	}

	void expr(const(IExpression) expression, size_t line = __LINE__)
	{
		emit(Instruction.expr(expression,line));
	}

	void go(const(IExpression) cond, Handle handle, size_t line = __LINE__)
	{
		emit(Instruction.go(cond,0,line));
		resolve(handle);
	}

	void newScope(size_t line = __LINE__)
	{
		emit(Instruction.newScope(line));
	}

	void delScope(size_t line = __LINE__)
	{
		emit(Instruction.delScope(line));
	}

	void ret(const(IExpression) expression, size_t line = __LINE__)
	{
		emit(Instruction.ret(expression,line));
	}

	void rngPopFront(const IExpression rng, size_t line = __LINE__)
	{
		emit(Instruction.rngPopFront(rng,line));
	}
}