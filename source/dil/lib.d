module dil.lib;

import dil.val;
import dil.exception;

DilTable dilTLSScope;

final class DilImportCallable : IDilCallable
{
	DilVal[dstring] cache;
	IDilImportRes[] ress;
	this()(IDilImportRes[] ress)
	{
		this.ress = ress;
	}

	IDilCallable context(DilVal val) @safe
	{
		return this;
	}

	DilVal call(DilVal[] args...) @safe
	{
		dstring dir = args[0].get!dstring;

		{
			DilVal* chck = dir in cache;
			if(chck !is null)
				return *chck;
		}

		foreach(res; ress)
			if(res.canResolve(dir))
			{
				DilVal tmp = res.resolve(dir);
				cache[dir] = tmp;
				return tmp;
			}
		import std.conv : text;
		throw new DilException("Could not resolve '"~dir.text~"'.");
	}

	size_t toHash() @safe nothrow inout
	{
		import core.internal.hash : hashOf;
		return this.hashOf;
	}
}

__gshared string[] importDirs = [];
__gshared IntegratedModResFunc[dstring] integratedModules;

shared static this()
{
	import dil.std.io;
	import dil.std.math;
	import dil.std.blob;
	import dil.std.file;
	import dil.std.random;
	import dil.std.gc;
	import dil.std.time;
	import dil.std.thread;
	integratedModules = [
		"std.io"	: &std_io_dil_module_fnc!(),
		"std.math"	: &std_math_dil_module_fnc!(),
		"std.blob"	: &std_blob_dil_module_fnc!(),
		"std.file"	: &std_file_dil_module_fnc!(),
		"std.random": &std_random_dil_module_fnc!(),
		"std.gc"	: &std_gc_dil_module_fnc!(),
		"std.time"	: &std_time_dil_module_fnc!(),
		"std.thread": &std_thread_dil_module_fnc!(),
	];
}

DilImportCallable makeDefDilImportCallable()()
{
	IDilImportRes[] ress = [new IntegratedModuleRes(integratedModules.dup)];

	foreach(d; importDirs)
		ress ~= new FileModuleRes(d);

	return new DilImportCallable(ress);
}

void defInitDilTLS(DilTable tbl)
{
	tbl[DilVal("import"d)] = DilVal(makeDefDilImportCallable());

	tbl[DilVal("int"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		import std.math : trunc;
		dilEnforce!DilException(args.length == 1,"'int' takes 1 argument.");
		import std.conv : to;
		if(args[0].type == DilVal.Type.string_)
			return DilVal(args[0].get!dstring.to!ptrdiff_t);
		else if(args[0].type == DilVal.Type.real_)
			return DilVal( cast(ptrdiff_t) args[0].get!real.trunc );
		else
			return DilVal(cast(ptrdiff_t) args[0]);
	}));

	tbl[DilVal("real"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		import std.math : trunc;
		dilEnforce!DilException(args.length == 1,"'real' takes 1 argument.");
		import std.conv : to;
		if(args[0].type == DilVal.Type.string_)
			return DilVal(args[0].get!dstring.to!real);
		else
			return DilVal(cast(real) args[0]);
	}));

	tbl[DilVal("char"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'char' takes 1 argument.");
		return DilVal(cast(dchar) args[0]);
	}));

	tbl[DilVal("string"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'string' takes 1 argument.");
		return DilVal(cast(dstring) args[0]);
	}));

	tbl[DilVal("classOf"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'classOf' takes 1 argument.");

		if(args[0].type == DilVal.Type.class_)
			return args[0];

		return DilVal(args[0].get!DilInst.classData);
	}));

	tbl[DilVal("table"d)]= DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'table' takes 1 argument.");
		
		if(args[0].type == DilVal.Type.array)
		{
			DilVal[] arr = args[0].get!(DilVal[]);
			DilTable tbl = new DilTable;
			foreach(k,ref v; arr)
				tbl[DilVal(k)] = v;
			return DilVal(tbl);
		}
		else if(args[0].type == DilVal.Type.inst)
		{
			return DilVal(args[0].get!DilInst.instData);
		}
		else
			return DilVal(args[0].get!DilTable);
	}));

	tbl[DilVal("isBool"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isBool' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.bool_);
	}));

	tbl[DilVal("isInt"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isInt' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.int_);
	}));	

	tbl[DilVal("isReal"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isReal' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.real_);
	}));

	tbl[DilVal("isChar"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isChar' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.char_);
	}));

	tbl[DilVal("isString"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isString' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.string_);
	}));

	tbl[DilVal("isArray"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isArray' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.array);
	}));

	tbl[DilVal("isTable"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isTable' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.table);
	}));

	tbl[DilVal("isInst"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isInst' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.inst);
	}));

	tbl[DilVal("isClass"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isClass' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.class_);
	}));

	tbl[DilVal("isCallable"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isCallable' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.callable);
	}));

	tbl[DilVal("isUserObj"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isUserObj' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.userObject);
	}));

	tbl[DilVal("isNull"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isNull' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.null_);
	}));

	tbl[DilVal("isVoid"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...){
		dilEnforce!DilException(args.length == 1,"'isVoid' takes 1 argument.");
		return DilVal(args[0].type == DilVal.Type.void_);
	}));
}

shared static this()
{
	import std.functional : toDelegate;
	initDilTLS = (&defInitDilTLS).toDelegate;
}

static this()
{
	dilTLSScope = new DilTable;
	initDilTLS(dilTLSScope);
}

alias DilTLSInitFunc = void delegate(DilTable tbl);
__gshared DilTLSInitFunc initDilTLS;

interface IDilImportRes
{
	bool canResolve(dstring dir) const @safe;
	DilVal resolve(dstring dir) @safe;
}

alias IntegratedModResFunc = DilVal function(dstring dir) @safe;

final class IntegratedModuleRes : IDilImportRes
{
	IntegratedModResFunc[dstring] integrated;

	this()(IntegratedModResFunc[dstring] integrated)
	{
		this.integrated = integrated;
	}

	bool canResolve(dstring dir) const @safe { return (dir in integrated) !is null; }
	DilVal resolve(dstring dir) @safe { return integrated[dir](dir); }
}

final class FileModuleRes : IDilImportRes
{
	import std.path;
	dstring folder;
	this(S)(S folder)
	{
		import std.array : array;
		import std.conv : dtext;
		this.folder = folder.asAbsolutePath.asNormalizedPath.dtext;
	}

	static size_t splitDir(size_t n)(return scope ref dstring[n] buf, dstring dir) @safe
	{
		import std.format : format;
		size_t bufLoc = 0;
		size_t prevPos = 0;
		size_t pos = 0;

		for(;;pos++)
		{
			if(pos == dir.length)
			{
				buf[bufLoc++] = dir[prevPos..pos];
				return bufLoc;
			}
			if(dir[pos] == '.')
			{
				buf[bufLoc++] = dir[prevPos..pos];
				prevPos = pos+1;
				if(bufLoc >= buf.length)
				{
					enum msg = format!"Can't have a module dir deeper than %s. ('%%s')"(buf.length);
					throw new DilException(format!msg(dir));
				}
			}
		}
	}

	bool canResolve(dstring dir) const @safe
	{
		import std.file : exists, isDir;
		dstring[16] buf;
		buf[0] = folder;
		scope dstring[] moduleSplitPath = buf[0..1+splitDir(buf[1..$],dir)];
		auto modulePath = buildPath(moduleSplitPath).setExtension("dil"d);
		return exists(modulePath) && !isDir(modulePath);
	}

	DilVal resolve(dstring dir) @safe
	{
		import std.file : readText;
		import dil.parser : compile;

		dstring[16] buf;
		buf[0] = folder;
		scope dstring[] moduleSplitPath = buf[0..1+splitDir(buf[1..$],dir)];
		auto modulePath = buildPath(moduleSplitPath).setExtension("dil"d);

		return modulePath.readText.compile.call(null);
	}
}