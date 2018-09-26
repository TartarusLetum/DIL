module dil.std.gc;

import dil.val;

DilVal std_gc_dil_module_fnc()(dstring dir) @safe
{
	DilTable tbl = new DilTable;
	
	import core.memory : GC;

	tbl[DilVal("collect"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		GC.collect();
		return DilVal.init;
	}));

	tbl[DilVal("enable"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		GC.enable();
		return DilVal.init;
	}));

	tbl[DilVal("disable"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		GC.disable();
		return DilVal.init;
	}));

	return DilVal(tbl);
}