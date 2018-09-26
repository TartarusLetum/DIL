module dil.std.math;

import dil.val;
import dil.exception;

DilVal std_math_dil_module_fnc()(dstring dir) @safe
{
	DilTable tbl = new DilTable;

	import std.math;
	static foreach(VAR; [
		"E"d
		,"PI"d
		,"PI_2"d
		,"PI_4"d
		,"M_1_PI"d
		,"M_2_PI"d
		,"M_2_SQRTPI"d
		,"LN10"d
		,"LN2"d
		,"LOG2"d
		,"LOG2E"d
		,"LOG2T"d
		,"LOG10E"d
		,"SQRT2"d
		,"SQRT1_2"d
	])
	{
		mixin("tbl[DilVal(VAR)] = DilVal("~VAR~");");
	}

	tbl[DilVal("POS_INF"d)] = DilVal(real.infinity);
	tbl[DilVal("NEG_INF"d)] = DilVal(-real.infinity);
	tbl[DilVal("INT_MAX"d)] = DilVal(ptrdiff_t.max);
	tbl[DilVal("INT_MIN"d)] = DilVal(ptrdiff_t.min);

	import dil.meta;
	static foreach(FNC; [
		"sqrt"d,
		"cbrt"d,
		"hypot"d,
		"sin"d,
		"cos"d,
		"tan"d,
		"asin"d,
		"acos"d,
		"atan"d,
		"atan2"d,
		"sinh"d,
		"cosh"d,
		"tanh"d,
		"asinh"d,
		"acosh"d,
		"atanh"d,
		"ceil"d,
		"floor"d,
		"round"d,
		"lround"d,
		"trunc"d,
		"rint"d,
		"lrint"d,
		"nearbyint"d,
		"rndtol"d,
		"exp"d,
		"exp2"d,
		"expm1"d,
		"ldexp"d,
		"log"d,
		"log2"d,
		"log10"d,
		"logb"d,
		"ilogb!real"d,
		"log1p"d,
		"scalbn"d,
		"fmod"d,
		"modf"d,
		"remainder"d,
		"fdim"d,
		"fmax"d,
		"fmin"d,
		"fma"d,
		"nextDown"d,
		"nextUp"d,
		"NaN"d,
		"getNaNPayload"d,
		"isIdentical"d
	])
	{
		mixin("tbl[DilVal(FNC)] = DilVal(makeDilCallable(&("~FNC~")));");
	}

	import std.format : format;

	tbl[DilVal("abs"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'abs'. There are %s."(args.length));
		
		if(args[0].type == DilVal.Type.real_)
			return DilVal(fabs(args[0].get!real));
		else
			return DilVal(abs(cast(ptrdiff_t) args[0]));
	}));

	tbl[DilVal("poly"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		dilEnforce!DilException(args.length > 1, format!"Expecting 2 args in 'poly'. There are %s."(args.length));
		
		real x = cast(real) args[0];
		DilVal[] dim = args[1].get!(DilVal[]);

		import std.experimental.allocator;
		import std.experimental.allocator.mallocator;
		import std.experimental.allocator.showcase;

		StackFront!(64,Mallocator) alloc;

		real[] a = alloc.makeArray!real(dim.length);

		scope(exit) alloc.dispose(a);

		foreach(i,ref v; dim)
			a[i] = cast(real)v;
		
		auto ret = poly(x,a);
		return DilVal(ret);
	}));

	tbl[DilVal("nextPow2"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'nextPow2'. There are %s."(args.length));
		
		if(args[0].type == DilVal.Type.real_)
			return DilVal(nextPow2(args[0].get!real));
		else
			return DilVal(nextPow2(cast(ptrdiff_t) args[0]));
	}));

	tbl[DilVal("truncPow2"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'truncPow2'. There are %s."(args.length));
		
		if(args[0].type == DilVal.Type.real_)
			return DilVal(truncPow2(args[0].get!real));
		else
			return DilVal(truncPow2(cast(ptrdiff_t) args[0]));
	}));

	tbl[DilVal("quantize"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 2, format!"Expecting 2 args in 'quantize'. There are %s."(args.length));
		return DilVal(quantize(cast(real) args[0],cast(real) args[1]));
	}));

	tbl[DilVal("approxEqual"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 2, format!"Expecting 2 args in 'approxEqual'. There are %s."(args.length));
		return DilVal(approxEqual(cast(real) args[0],cast(real) args[1]));
	}));

	tbl[DilVal("feqrel"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 2, format!"Expecting 2 args in 'feqrel'. There are %s."(args.length));
		return DilVal(feqrel(cast(real) args[0],cast(real) args[1]));
	}));

	tbl[DilVal("nextafter"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 2, format!"Expecting 2 args in 'nextafter'. There are %s."(args.length));
		return DilVal(nextafter(cast(real) args[0],cast(real) args[1]));
	}));

	tbl[DilVal("cmp"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 2, format!"Expecting 2 args in 'cmp'. There are %s."(args.length));
		return DilVal(cmp(cast(real) args[0],cast(real) args[1]));
	}));

	tbl[DilVal("isFinite"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'isFinite'. There are %s."(args.length));
		return DilVal(isFinite(cast(real) args[0]));
	}));

	tbl[DilVal("isInfinity"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'isInfinity'. There are %s."(args.length));
		return DilVal(isInfinity(cast(real) args[0]));
	}));

	tbl[DilVal("isNaN"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'isNan'. There are %s."(args.length));
		return DilVal(isNaN(cast(real) args[0]));
	}));

	tbl[DilVal("isNormal"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'isNormal'. There are %s."(args.length));
		return DilVal(isNormal(cast(real) args[0]));
	}));

	tbl[DilVal("isSubnormal"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'isSubnormal'. There are %s."(args.length));
		return DilVal(isSubnormal(cast(real) args[0]));
	}));

	tbl[DilVal("isNormal"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'isNormal'. There are %s."(args.length));
		return DilVal(isNormal(cast(real) args[0]));
	}));

	tbl[DilVal("signbit"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'signbit'. There are %s."(args.length));
		return DilVal(cast(bool) signbit(cast(real) args[0]));
	}));

	tbl[DilVal("sgn"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'sgn'. There are %s."(args.length));
		return DilVal(sgn(cast(real) args[0]));
	}));

	tbl[DilVal("copysign"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 2, format!"Expecting 2 args in 'copysign'. There are %s."(args.length));
		return DilVal(copysign(cast(real) args[0],cast(real) args[1]));
	}));

	tbl[DilVal("isPowerOf2"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1, format!"Expecting 1 arg in 'isPowerOf2'. There are %s."(args.length));
		return DilVal(isPowerOf2(cast(real) args[0]));
	}));

	return DilVal(tbl);
}