module dil.std.io;

import dil.val;

DilVal std_io_dil_module_fnc()(dstring dir) @safe
{
	import std.stdio;
	DilTable tbl = new DilTable;

	tbl[DilVal("print"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		foreach(ref arg; args)
			write(arg.toString);
		return DilVal.init;
	}));
	tbl[DilVal("println"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		foreach(ref arg; args)
			write(arg.toString);
		writeln();
		return DilVal.init;
	}));
	tbl[DilVal("readln"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		return DilVal(readln!dstring[0..$-1]);
	}));

	return DilVal(tbl);
}