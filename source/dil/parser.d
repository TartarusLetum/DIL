module dil.parser;

import std.range;
import std.algorithm : equal;
import std.format : format;
import dil.exception;
import dil.irbuilder;
import dil.irexpr;
import dil.val;

@safe:
auto compile(RNG)(RNG rng, string file = __FILE__)
if(isForwardRange!RNG && is(ElementType!RNG : dchar))
{
	StrWrapper!RNG wrapper = new StrWrapper!RNG(rng,file);
	DilIRBuilder builder = DilIRBuilder(file);
	builder.dilMod(wrapper);
	return builder.build();
}

auto compileFile(string file)
{
	import std.file : readText;
	return readText(file).compile(file);
}

private:
final class StrWrapper(RNG)
if(isForwardRange!RNG && is(ElementType!RNG : dchar))
{
	RNG rng;
	string file;
	size_t line = 1;

	this()(RNG trng, string file)
	{
		rng = trng;
		this.file = file;
	}

	private this()(RNG trng, string file, size_t line)
	{
		rng = trng;
		this.file = file;
		this.line = line;
	}

	dchar front()() @property { return rng.front; }
	bool empty()() @property { return rng.empty; }
	void popFront()()
	{
		if(rng.front == '\n')
			line++;
		rng.popFront;
	}

	StrWrapper!RNG save()()
	{
		return new StrWrapper!RNG(rng.save,file,line);
	}
}

dstring moveIdent(RNG)(ref StrWrapper!RNG wrapper)
{
	wrapper.skipWS;
	import std.uni : isAlpha, isAlphaNum;
	if(wrapper.empty || !(wrapper.front.isAlpha || wrapper.front == '_'))
		return null;
	dstring ret = ""d;
	for(;!wrapper.empty;wrapper.popFront)
		if(wrapper.front.isAlphaNum || wrapper.front == '_')
			ret ~= wrapper.front;
		else
			return ret;
	return ret;
}

void skipWS(RNG)(ref StrWrapper!RNG wrapper)
{
	import std.uni : isWhite;
	for(;!wrapper.empty;wrapper.popFront)
	{
		if(!wrapper.front.isWhite)
		{
			if(wrapper.front == '/')
			{
				auto tmp = wrapper.save;
				wrapper.popFront;
				if(wrapper.front == '/')
				{
					for(;!wrapper.empty;wrapper.popFront)
						if(wrapper.front == '\n' || wrapper.front == '\r')
						{
							wrapper.popFront;
							break;
						}
				}
				else if(wrapper.front == '*')
				{
					wrapper.popFront;
					for(;;wrapper.popFront)
					{
						dilEnforce!DilException(!wrapper.empty,"Encountered EOF before '*/'.");
						if(wrapper.front == '*')
						{
							wrapper.popFront;
							if(wrapper.front == '/')
							{
								wrapper.popFront;
								break;
							}
						}
					}
				}
				else if(wrapper.front == '+')
				{
					wrapper.popFront;
					size_t count = 1;

					for(;;wrapper.popFront)
					{
						dilEnforce!DilException(!wrapper.empty,"Encountered EOF before '*/'.");
						if(wrapper.front == '+')
						{
							wrapper.popFront;
							if(wrapper.front == '/')
							{
								count--;
								if(count == 0)
								{
									wrapper.popFront;
									break;
								}
							}
						}
						else if(wrapper.front == '/')
						{
							wrapper.popFront;
							if(wrapper.front == '+')
								count++;
						}
					}
				}
				else
				{
					wrapper = tmp;
					return;
				}
			}
			else
				return;
		}
	}
}

void expect(RNG)(ref StrWrapper!RNG wrapper, dstring seq)
{
	wrapper.skipWS;
	auto tmp = wrapper.take(seq.length);
	dilEnforce!DilException(tmp.equal(seq),format("Expecting '%s' on line %s in '%s'. Found '%s' instead.",seq,wrapper.line,wrapper.file,tmp));
}

dstring moveOp(RNG)(ref StrWrapper!RNG wrapper)
{
	wrapper.skipWS;

	dstring s = "";

	switch(wrapper.front)
	{
		case '+':
		case '-':
		case '&':
		case '|':
		s ~= wrapper.front;
		wrapper.popFront;
		if(wrapper.front == s[0] || wrapper.front == '=')
		{
			s ~= wrapper.front;
			wrapper.popFront;
		}
		return s;

		case '*':
		case '/':
		case '%':
		case '!':
		case '=':
		case '~':
		s ~= wrapper.front;
		wrapper.popFront;
		if(wrapper.front == '=')
		{
			s ~= wrapper.front;
			wrapper.popFront;
		}
		return s;

		case '^':
		case '<':
		s ~= wrapper.front;
		wrapper.popFront;
		if(wrapper.front == s[0])
		{
			s ~= wrapper.front;
			wrapper.popFront;
		}
		if(wrapper.front == '=')
		{
			s ~= wrapper.front;
			wrapper.popFront;
		}
		return s;

		case '>':
		s ~= wrapper.front;
		wrapper.popFront;
		if(wrapper.front == s[0])
		{
			s ~= wrapper.front;
			wrapper.popFront;
			if(wrapper.front == s[0])
			{
				s ~= wrapper.front;
				wrapper.popFront;
			}
		}
		if(wrapper.front == '=')
		{
			s ~= wrapper.front;
			wrapper.popFront;
		}
		return s;
		default:
		return null;
	}
}

void expectOp(RNG)(ref StrWrapper!RNG wrapper, dstring seq)
{
	dilEnforce!DilException(wrapper.moveOp == seq,format!"Expecting '%s' on line %s in '%s'."(seq,wrapper.line,wrapper.file));
}

bool checkAndCondConsume(RNG)(ref StrWrapper!RNG wrapper, dstring seq)
{
	wrapper.skipWS;
	StrWrapper!RNG tmp = wrapper.save;
	if(wrapper.take(seq.length).equal(seq))
		return true;
	else
	{
		wrapper = tmp;
		return false;
	}
}

bool checkAndCondConsumeOp(RNG)(ref StrWrapper!RNG wrapper, dstring seq)
{
	StrWrapper!RNG tmp = wrapper.save;
	if(wrapper.moveOp == seq)
		return true;
	else
	{
		wrapper = tmp;
		return false;
	}
}

void dilMod(RNG)(ref DilIRBuilder builder,ref StrWrapper!RNG wrapper) @trusted
{
	ContBreakPair*[dstring] lbls;
	ContBreakPair pr = ContBreakPair(builder.newHandle,builder.newHandle,0);
	builder.bindHandle(pr[0]);
	while(builder.statement(wrapper,0,lbls,&pr)){}
	builder.bindHandle(pr[1]);
	builder.ret(null,wrapper.line);
}

void emitGoto(ref DilIRBuilder builder, DilIRBuilder.Handle handle, ptrdiff_t scopeDiff, size_t line)
{
	if(scopeDiff < 0)
		for(ptrdiff_t i = 0; i < -scopeDiff; i++)
			builder.newScope(line);
	else
		for(ptrdiff_t i = 0; i < scopeDiff; i++)
			builder.delScope(line);
	builder.go(null,handle,line);
}

import std.typecons : Tuple;
alias ContBreakPair = Tuple!(DilIRBuilder.Handle,DilIRBuilder.Handle,ptrdiff_t); //continue, break

bool statement(RNG)(ref DilIRBuilder builder,ref StrWrapper!RNG wrapper,ptrdiff_t scopeNum,ref ContBreakPair*[dstring] lbldStatements, scope ContBreakPair* parent, dstring lbl = null) @trusted
{
	auto savedWrapper = wrapper.save;

	dstring s = wrapper.moveIdent;
	if(s is null)
	{
		if(wrapper.empty)
			return false;
		if(wrapper.front == ':')
			goto expr;
		if(wrapper.front == '}')
		{
			wrapper.popFront;
			return false;
		}
		wrapper.expect("{"d);
		builder.newScope(wrapper.line);
		while(builder.statement(wrapper,scopeNum+1,lbldStatements,parent)){}
		builder.delScope(wrapper.line);
		return true;
	}

	switch(s)
	{
		case "while":
		{
			size_t condLine = wrapper.line;
			wrapper.expect("(");
			const(IExpression) cond = wrapper.expression;	
			wrapper.expect(")");
			ContBreakPair contBreak = ContBreakPair(builder.newHandle,builder.newHandle,scopeNum);
			if(lbl !is null)
				lbldStatements[lbl] = &contBreak;
			builder.go(null,contBreak[0],condLine);
			auto toBegin = builder.newHandle;
			builder.bindHandle(toBegin);
			builder.statement(wrapper,scopeNum,lbldStatements,&contBreak);
			builder.bindHandle(contBreak[0]);
			try
			{
				if(cond.ctEval)
					builder.go(null,toBegin,condLine);
			}
			catch(DilCTEvalException e)
			{
				builder.go(cond,toBegin,condLine);
			}
			builder.bindHandle(contBreak[1]);
			if(lbl !is null)
				lbldStatements.remove(lbl);
			return true;
		}
		case "for":
		{
			ContBreakPair contBreak = ContBreakPair(builder.newHandle,builder.newHandle,scopeNum);
			auto toAfterOp = builder.newHandle;
			if(lbl !is null)
				lbldStatements[lbl] = &contBreak;
			wrapper.expect("(");
			builder.newScope(wrapper.line);
			builder.statement(wrapper,scopeNum,lbldStatements,&contBreak);
			size_t condLine = wrapper.line;
			const(IExpression) cond = wrapper.expression;
			wrapper.expect(";");
			size_t opLine = wrapper.line;
			const(IExpression) op = wrapper.expression;
			wrapper.expect(")");
			builder.go(null,toAfterOp,condLine);
			auto toBegin = builder.newHandle;
			builder.bindHandle(toBegin);
			builder.statement(wrapper,scopeNum,lbldStatements,&contBreak);
			builder.bindHandle(contBreak[0]);
			builder.expr(op,opLine);
			builder.bindHandle(toAfterOp);
			try
			{
				if(cond.ctEval)
					builder.go(null,toBegin,condLine);
			}
			catch(DilCTEvalException e)
			{
				builder.go(cond,toBegin,condLine);
			}
			builder.bindHandle(contBreak[1]);
			builder.delScope(wrapper.line);
			if(lbl !is null)
				lbldStatements.remove(lbl);
			return true;
		}
		case "foreach":
		{
			ContBreakPair contBreak = ContBreakPair(builder.newHandle,builder.newHandle,scopeNum);
			if(lbl !is null)
				lbldStatements[lbl] = &contBreak;
			auto toAfterOp = builder.newHandle;
			wrapper.expect("(");
			builder.newScope(wrapper.line);
			dstring first = wrapper.moveIdent;
			dilEnforce!DilException(first.length > 0, format!"Expecting an identifier after '(' on line %s in '%s'."(wrapper.line,wrapper.file));
			builder.localDecl(first,new ValueExpr(DilVal.init),wrapper.line);
			wrapper.skipWS;
			dstring second = null;
			if(wrapper.front == ',')
			{
				wrapper.popFront;
				second = wrapper.moveIdent;
				dilEnforce!DilException(second.length > 0, format!"Expecting an identifier after ',' on line %s in '%s'."(wrapper.line,wrapper.file));
				builder.localDecl(second,new ValueExpr(DilVal.init),wrapper.line);
			}
			wrapper.expect(";");
			const(IExpression) rngCreate = new MakeRngExpr(wrapper.expression);
			builder.localDecl("$rng"d,rngCreate,wrapper.line);
			builder.go(null,toAfterOp,wrapper.line);
			auto toBegin = builder.newHandle;
			builder.bindHandle(toBegin);
			if(second !is null)
			{
				builder.assign(new LocalAccessExpr(first),new LdKFromRngExpr(new LocalAccessExpr("$rng"d)),wrapper.line);
				builder.assign(new LocalAccessExpr(second),new LdVFromRngExpr(new LocalAccessExpr("$rng"d)),wrapper.line);
			}
			else
				builder.assign(new LocalAccessExpr(first),new LdVFromRngExpr(new LocalAccessExpr("$rng"d)),wrapper.line);
			wrapper.expect(")");
			builder.statement(wrapper,scopeNum,lbldStatements,&contBreak);
			builder.bindHandle(contBreak[0]);
			builder.rngPopFront(new LocalAccessExpr("$rng"d),wrapper.line);
			builder.bindHandle(toAfterOp);
			builder.go(new PrefixExpr!"!"(new IsEmptyRngExpr(new LocalAccessExpr("$rng"d))),toBegin,wrapper.line);
			builder.bindHandle(contBreak[1]);
			builder.delScope(wrapper.line);
			if(lbl !is null)
				lbldStatements.remove(lbl);
			return true;
		}
		case "if":
		{
			wrapper.expect("(");
			const(IExpression) cond = wrapper.expression;
			wrapper.expect(")");
			auto toElse = builder.newHandle;
			builder.go(new PrefixExpr!"!"(cond),toElse,wrapper.line);
			builder.statement(wrapper,scopeNum,lbldStatements,parent,lbl);
			
			auto tmpWrapper = wrapper.save;
			if(wrapper.moveIdent == "else")
			{
				auto toEnd = builder.newHandle;
				builder.go(null,toEnd,wrapper.line);
				builder.bindHandle(toElse);
				builder.statement(wrapper,scopeNum,lbldStatements,parent,lbl);
				builder.bindHandle(toEnd);
			}
			else
			{
				builder.bindHandle(toElse);
				wrapper = tmpWrapper;
			}

			return true;
		}
		case "local":
		{
			dstring ident = wrapper.moveIdent;
			dilEnforce!DilException(ident !is null, format!"Expecting an identifier after 'local' on line %s in '%s'."(wrapper.line,wrapper.file));
			wrapper.expectOp("=");
			builder.localDecl(ident,wrapper.expression,wrapper.line);
			wrapper.expect(";");
			return true;
		}
		case "global":
		{
			dstring ident = wrapper.moveIdent;
			dilEnforce!DilException(ident !is null, format!"Expecting an identifier after 'global' on line %s in '%s'."(wrapper.line,wrapper.file));
			wrapper.expectOp("=");
			builder.globalDecl(ident,wrapper.expression,wrapper.line);
			wrapper.expect(";");
			return true;
		}
		case "return":
		if(wrapper.checkAndCondConsume(";"))
			builder.ret(null,wrapper.line);
		else
		{
			builder.ret(wrapper.expression,wrapper.line);
			wrapper.expect(";");
		}
		return true;
		case "break":
		{
			dstring ident = wrapper.moveIdent;
			ContBreakPair* pr;
			if(ident !is null)
				pr = lbldStatements[ident];
			else
			{
				dilEnforce!DilException(parent !is null,"'break' must be in a loop.",wrapper.file,wrapper.line);
				pr = parent;
			}
			builder.emitGoto((*pr)[1],scopeNum-(*pr)[2],wrapper.line);
			wrapper.expect(";");
		}
		return true;
		case "continue":
		{
			dstring ident = wrapper.moveIdent;
			ContBreakPair* pr;
			if(ident !is null)
				pr = lbldStatements[ident];
			else
			{
				dilEnforce!DilException(parent !is null,"'continue' must be in a loop.",wrapper.file,wrapper.line);
				pr = parent;
			}
			builder.emitGoto((*pr)[0],scopeNum-(*pr)[2],wrapper.line);
			wrapper.expect(";");
		}
		return true;
		case "this":
		{
			dstring ident = wrapper.moveIdent;
			if(ident !is null)
			{
				builder.ctorDecl(ident,wrapper.funcLitExpr);
				return true;
			}
		}
		goto default;
		default:
		{
			wrapper.skipWS;
			if(wrapper.front == ':')
			{
				wrapper.popFront;
				builder.statement(wrapper,scopeNum,lbldStatements,parent,s);
				return true;
			}

			wrapper = savedWrapper;
			expr:
			builder.expr(wrapper.expression,wrapper.line);
			wrapper.expect(";");
			return true;
		}
	}
}

const(IExpression) expression(RNG)(ref StrWrapper!RNG wrapper)
{
	return wrapper.assignExpr;
}

const(IExpression) assignExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const lhs = wrapper.ternaryExpr;
	auto tmp = wrapper.save;
	dstring op = wrapper.moveOp;
	switch(op)
	{
		case "=":
		return new AssignExpr(lhs,wrapper.expression);

		static foreach(match; [
			"+=",
			"-=",
			"*=",
			"/=",
			"%=",
			"^^=",
			"&=",
			"|=",
			"^=",
			"~="
		])
		{
			case match:
			return new AssignExpr(lhs,new BinaryExpr!(match[0..$-1])(lhs,wrapper.expression));
		}
		default:
		//dilEnforce!DilException(0,format!"'%s' is not a valid assignment."(match),wrapper.file,wrapper.line);
		wrapper = tmp;
		return lhs;
	}
}

const(IExpression) ternaryExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const cond = wrapper.logOrExpr;
	wrapper.skipWS();
	if(wrapper.front == '?')
	{
		wrapper.popFront;
		const t = wrapper.logOrExpr;
		wrapper.skipWS();
		wrapper.expectOp(":");
		const f = wrapper.ternaryExpr;
		return new TernaryExpr(cond,t,f);
	}
	else
		return cond;
}

const(IExpression) logOrExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.logAndExpr;
	if(wrapper.checkAndCondConsumeOp("||"))
		return new OrShortCircuitExpr(l,wrapper.logOrExpr);
	else
		return l;
}

const(IExpression) logAndExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.bitOrExpr;
	if(wrapper.checkAndCondConsumeOp("&&"))
		return new AndShortCircuitExpr(l,wrapper.logAndExpr);
	else
		return l;
}

const(IExpression) bitOrExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.bitAndExpr;
	if(wrapper.checkAndCondConsumeOp("|"))
		return new BinaryExpr!"|"(l,wrapper.bitOrExpr);
	else
		return l;
}

const(IExpression) bitXorExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.bitAndExpr;
	if(wrapper.checkAndCondConsumeOp("^"))
		return new BinaryExpr!"^"(l,wrapper.bitXorExpr);
	else
		return l;
}

const(IExpression) bitAndExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.cmpExpr;
	if(wrapper.checkAndCondConsumeOp("&"))
		return new BinaryExpr!"&"(l,wrapper.bitAndExpr);
	else
		return l;
}

const(IExpression) cmpExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.shiftExpr;
	auto tmpWrapper = wrapper.save;
	dstring op = wrapper.moveOp;
	switch(op)
	{
		static foreach(match; [
			"==",
			"!=",
			"<",
			">",
			"<=",
			">="
		])
		{
			case match:
			return new CmpExpr!match(l,wrapper.cmpExpr);
		}
		default:
		wrapper = tmpWrapper;
		if(wrapper.moveIdent == "in")
			return new BinaryExpr!"in"(l,wrapper.cmpExpr);
		else
		{
			wrapper = tmpWrapper;
			return l;
		}
	}
}

const(IExpression) shiftExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.addExpr;
	auto tmpWrapper = wrapper.save;
	dstring op = wrapper.moveOp;
	switch(op)
	{
		static foreach(match; [
			"<<",
			">>",
			">>>"
		])
		{
			case match:
			return new BinaryExpr!match(l,wrapper.shiftExpr);
		}
		default:
			wrapper = tmpWrapper;
			return l;
	}
}

const(IExpression) addExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.mulExpr;
	auto tmpWrapper = wrapper.save;
	dstring op = wrapper.moveOp;
	switch(op)
	{
		static foreach(match; [
			"+",
			"-",
			"~"
		])
		{
			case match:
			return new BinaryExpr!match(l,wrapper.addExpr);
		}
		default:
			wrapper = tmpWrapper;
			return l;
	}
}

const(IExpression) mulExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.unaryExpr;
	auto tmpWrapper = wrapper.save;
	dstring op = wrapper.moveOp;
	switch(op)
	{
		static foreach(match; [
			"*",
			"/",
			"%"
		])
		{
			case match:
			return new BinaryExpr!match(l,wrapper.mulExpr);
		}
		default:
			wrapper = tmpWrapper;
			return l;
	}
}

const(IExpression) unaryExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	auto tmpWrapper = wrapper.save;
	dstring op = wrapper.moveOp;
	switch(op)
	{
		static foreach(match; [
			"-",
			"+",
			"!",
			"~"
		])
		{
			case match:
			return new PrefixExpr!match(wrapper.unaryExpr);
		}

		case "$":
		return new DollarExpr(wrapper.unaryExpr);

		case "++":
		return new PreIncrExpr(wrapper.unaryExpr);
		case "--":
		return new PreDecrExpr(wrapper.unaryExpr);

		default:
		wrapper = tmpWrapper;
		return wrapper.powExpr;
	}
}

const(IExpression) powExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	const l = wrapper.postExpr;
	if(wrapper.checkAndCondConsumeOp("^^"))
		return new BinaryExpr!"^^"(l,wrapper.powExpr);
	else
		return l;
}

const(IExpression) postExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	return wrapper.parsePost(wrapper.primaryExpr);
}

const(IExpression) parsePost(RNG)(ref StrWrapper!RNG wrapper, const(IExpression) inner)
{
	wrapper.skipWS;
	if(wrapper.front == '.')
	{
		wrapper.popFront;
		dstring memb = wrapper.moveIdent;
		return wrapper.parsePost(new MemberAccessExpr(inner,memb));
	}
	else if(wrapper.front == '[')
	{
		wrapper.popFront;
		const ndx = wrapper.expression;
		wrapper.skipWS;
		wrapper.expect("]");
		return wrapper.parsePost(new IndexAccessExpr(inner,ndx));
	}
	else if(wrapper.front == '(')
	{
		wrapper.popFront;
		const(IExpression)[] args;
		wrapper.skipWS;
		if(wrapper.front == ')')
		{
			wrapper.popFront;
			return wrapper.parsePost(new CallExpr(inner,args));
		}
		for(;;)
		{
			args ~= wrapper.expression;
			wrapper.skipWS;
			if(wrapper.front != ',')
			{
				wrapper.expect(")");
				break;
			}
			else
				wrapper.popFront;
		}

		return wrapper.parsePost(new CallExpr(inner,args));
	}
	else if(wrapper.front == '+')
	{
		auto tmp = wrapper.save;
		wrapper.popFront;
		if(wrapper.front != '+')
		{
			wrapper = tmp;
			return inner;
		}
		wrapper.popFront;
		return wrapper.parsePost(new PostIncrExpr(inner));
	}
	else if(wrapper.front == '-')
	{
		auto tmp = wrapper.save;
		wrapper.popFront;
		if(wrapper.front != '-')
		{
			wrapper = tmp;
			return inner;
		}
		wrapper.popFront;
		return wrapper.parsePost(new PostDecrExpr(inner));
	}
	else
		return inner;
}

const(IExpression) primaryExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	import std.uni : isNumber;
	wrapper.skipWS;
	if(wrapper.front == '"' || wrapper.front == '`')
		return wrapper.strLitExpr;
	else if(wrapper.front == '\'')
		return wrapper.charLitExpr;
	else if(wrapper.front == ':')
	{
		wrapper.popFront;
		return new GlobalAccessExpr(wrapper.moveIdent);
	}
	else if(wrapper.front == '(')
	{
		wrapper.popFront;
		const expr = wrapper.expression;
		wrapper.expect(")");
		return expr;
	}
	else if(wrapper.front == '[')
	{
		wrapper.popFront;
		wrapper.skipWS;
		if(wrapper.front == ']')
		{
			wrapper.popFront;
			return new ValueExpr(cast(DilVal[])[]);
		}
		const(IExpression)[] args;
		const(IExpression)[] values;
		for(;;)
		{
			args ~= wrapper.expression;
			if(wrapper.checkAndCondConsume(":"))
			{
				values ~= wrapper.expression;
			}
			wrapper.skipWS;

			if(wrapper.front != ',')
			{
				wrapper.expect("]");
				break;
			}
			else
				wrapper.popFront;
		}
		if(values.length > 0)
		{
			dilEnforce!DilException(args.length == values.length, "Cannot mix array ctor with table ctor.",wrapper.file,wrapper.line);
			return new TblCtorExpr(args,values);
		}

		return new ArrCtorExpr(args);
	}
	else if(wrapper.front.isNumber)
		return wrapper.intLitExpr;
	else
	{
		dstring ident = wrapper.moveIdent;
		switch(ident)
		{
			case "true"d:
				return new ValueExpr(true);
			case "false"d:
				return new ValueExpr(false);
			case "null"d:
				return new ValueExpr(null);
			case "void"d:
				return new ValueExpr(DilVal.init);
			case "class"d:
				return wrapper.classLitExpr;
			case "function"d:
				return new FuncExpr(wrapper.funcLitExpr);
			case "property"d:
				return wrapper.propLitExpr;
			case "scope"d:
				return new LdScopeExpr;
			default:
				return new LocalAccessExpr(ident);
		}
	}
}

const(IExpression) strLitExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	dchar quote = wrapper.front;
	wrapper.popFront;
	dstring str;
	while(!wrapper.empty)
	{
		if(wrapper.front == '\\')
		{
			wrapper.popFront;
			str ~= wrapper.escSeq;
		}
		else if(wrapper.front == quote)
		{
			wrapper.popFront;
			return new ValueExpr(str);
		}
		else
		{
			str ~= wrapper.front;
			wrapper.popFront;
		}
	}

	throw new DilException("End of file encountered before closing quote.",wrapper.file,wrapper.line);	
}

const(IExpression) charLitExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	wrapper.popFront;
	dchar c;
	if(wrapper.front == '\\')
	{
		wrapper.popFront;
		c = wrapper.escSeq;
	}
	else
	{
		c = wrapper.front;
		wrapper.popFront;
	}
	dilEnforce!DilException(wrapper.front == '\'', "Expected single quote to close char literal.",wrapper.file,wrapper.line);
	wrapper.popFront;
	return new ValueExpr(c);
}

dchar escSeq(RNG)(ref StrWrapper!RNG wrapper)
{
	import std.conv : to;
	import std.range : takeExactly;
	dchar c;
	sw: switch(wrapper.front)
	{
		static foreach(mc; ["'"[0],'"','?','\\'])
		{
			case mc:
			c = mc;
			break sw;
		}

		static foreach(mc; "0abfnrtv")
		{
			case mc:
			mixin(`c = '\`~mc~`';`);
			break sw;
		}

		case 'x':
		wrapper.popFront;
		return cast(dchar)wrapper.takeExactly(2).to!uint(16);		

		case 'u':
		wrapper.popFront;
		return cast(dchar)wrapper.takeExactly(4).to!uint(16);
		
		case 'U':
		wrapper.popFront;
		return cast(dchar)wrapper.takeExactly(8).to!uint(16);

		default:
		import std.format : format;
		throw new DilException(format!"'%s' is not an escape sequence."(wrapper.front),wrapper.file,wrapper.line);
	}
	wrapper.popFront;
	return c;
}

const(IExpression) intLitExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	import std.uni : isNumber, isWhite;
	dchar[24] buf;
	size_t loc = 0;
	bool isFloat = false;
	
	void appnd()
	{
		dilEnforce!DilException(loc < buf.length, "Number is to big to handle.", wrapper.file, wrapper.line);
		buf[loc++] = wrapper.front;
		wrapper.popFront;
	}
	
	while(!wrapper.empty)
	{
		if(wrapper.front.isNumber)
			appnd();
		else if(wrapper.front == '.' || wrapper.front == 'e' || wrapper.front == 'E')
		{
			appnd();
			isFloat = true;
		}
		else
			break;
	}

	import std.conv : to;
	if(isFloat)
		return new ValueExpr(buf[0..loc].to!real);
	else
		return new ValueExpr(buf[0..loc].to!ptrdiff_t);
}

const(IExpression) classLitExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	DilIRBuilder builder = DilIRBuilder(wrapper.file);
	wrapper.expect("{");
	ContBreakPair*[dstring] lbldStatements;
	while(builder.statement(wrapper,0,lbldStatements,null)){}
	builder.ret(new LdScopeExpr,wrapper.line);
	return new DefineClassExpr(builder.build,builder.ctors);
}

IDilCallable funcLitExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	dstring[] args;
	dstring vararg = null;
	if(wrapper.checkAndCondConsume("("))
	{
		if(!wrapper.checkAndCondConsume(")"))
		{
			for(;;)
			{
				dstring arg = wrapper.moveIdent;
				dilEnforce!DilException(arg !is null, "Expected an identifier as an argument name.",wrapper.file,wrapper.line);
				args ~= arg;
				wrapper.skipWS;
				if(wrapper.front != ',')
					break;
				wrapper.popFront;
			}
			if(wrapper.checkAndCondConsume("..."))
			{
				vararg = args[$-1];
				args = args[0..$-1];
			}

			wrapper.expect(")");
		}
	}

	DilIRBuilder builder = DilIRBuilder(args,vararg,wrapper.file);
	wrapper.expect("{");
	ContBreakPair*[dstring] lbldStatements;
	while(builder.statement(wrapper,0,lbldStatements,null)){}
	builder.ret(null,wrapper.line);
	dilEnforce!DilException(builder.ctors.length == 0, "Useless ctors.",wrapper.file,wrapper.line);
	import dil.ir : DilFunc;
	return new DilFunc(builder.build);
}

const(IExpression) propLitExpr(RNG)(ref StrWrapper!RNG wrapper)
{
	wrapper.expect("{");
	DilProperty prop;
	dstring ident;
	for(;;)
	{
		ident = wrapper.moveIdent;
		if(ident is null)
			break;
		wrapper.expect("=");
		wrapper.expect("function");
		if(ident == "get")
			prop.getter = wrapper.funcLitExpr();
		else if(ident == "set")
			prop.setter = wrapper.funcLitExpr();
		else
			throw new DilException(format!"'%s' is not a property member."(ident),wrapper.file,wrapper.line);
		wrapper.expect(";");
	}
	wrapper.expect("}");

	return new ValueExpr(prop);
}