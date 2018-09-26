module dil.std.random;

import dil.val;
import dil.exception;

DilVal std_random_dil_module_fnc()(dstring dir) @safe
{
	DilTable tbl = new DilTable;
	
	import std.random;

	tbl[DilVal("uniform01"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		return DilVal(uniform01!real);
	}));

	tbl[DilVal("uniformInt"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		if(args.length == 0)
			return DilVal(uniform!ptrdiff_t());
		
		dilEnforce!DilException(args.length == 2, "Expecting 0 or 2 args in 'uniformInt'.");
		
		return DilVal(uniform!"[)"(args[0].get!ptrdiff_t,args[1].get!ptrdiff_t));
	}));

	tbl[DilVal("uniformReal"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		dilEnforce!DilException(args.length == 2, "Expecting 2 args in 'uniformReal'.");
		
		return DilVal(uniform!"[)"(cast(real) args[0],cast(real) args[1]));
	}));

	return DilVal(tbl);
}