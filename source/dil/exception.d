module dil.exception;

class DilException : Exception
{
	this()(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg,file,line);
	}
}

void dilEnforce(E : DilException,T,string file = __FILE__, size_t line = __LINE__)(lazy T val)
{
	import std.exception;
	enforce(val,new E(file,line));
}

void dilEnforce(E : DilException,T,S)(lazy T val, lazy S msg, string file = __FILE__, size_t line = __LINE__)
{
	import std.exception;
	import std.conv : text;
	enforce(val,new E(msg.text,file,line));
}