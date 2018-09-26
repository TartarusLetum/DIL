module dil.std.file;

import dil.meta;
import dil.val;
import dil.exception;
import dil.std.blob;

import std.mmfile;
import std.experimental.allocator;
import std.experimental.allocator.mallocator;

alias DefDilFile = DilFile!Mallocator;

DilVal std_file_dil_module_fnc()(dstring dir) @trusted
{
	DilTable tbl = new DilTable;	

	tbl[DilVal("File"d)] = DilVal(DefDilFile.dilClass);

	return DilVal(tbl);
}

final class DilFile(Allocator) : IDilBlob
{
	string filename;
	MmFile buf;
	size_t _pos = 0;

	this()(string filename, MmFile.Mode md) @trusted
	{
		buf = Allocator.instance.make!MmFile(filename,md,cast(ulong)0,null);
		this.filename = filename;
	}

	this()(string filename, MmFile.Mode md, size_t sz) @trusted
	{
		buf = Allocator.instance.make!MmFile(filename,md,sz,null);
		this.filename = filename;
	}

	final class DilBlobReader : IDilBlobReader
	{
		size_t _pos = 0;

		T readVal(T)() @trusted
		{
			import std.bitmanip : littleEndianToNative;
			ptrdiff_t crnt = _pos;
			_pos += T.sizeof;

			return (cast(ubyte[])(buf[crnt.._pos]))[0..T.sizeof].littleEndianToNative!(T,T.sizeof);
		}

		ubyte readUByte()
		{
			return readVal!ubyte;
		}
		byte readByte()
		{
			return readVal!byte;
		}
		ushort readUShort()
		{
			return readVal!ushort;
		}
		short readShort()
		{
			return readVal!short;
		}
		uint readUInt()
		{
			return readVal!uint;
		}
		int readInt()
		{
			return readVal!int;
		}
		ulong readULong()
		{
			return readVal!ulong;
		}
		long readLong()
		{
			return readVal!long;
		}
		dchar readUTF8Char() @trusted
		{
			import std.utf : decode;
			return decode(cast(char[])(buf[]),_pos);
		}
		dchar readUTF16Char() @trusted
		{
			import std.utf : decode;
			size_t end = size - size%wchar.sizeof;
			return decode(cast(wchar[])(buf[0..end]),_pos);
		}
		dchar readUTF32Char() @trusted
		{
			import std.utf : decode;
			size_t end = size - size%dchar.sizeof;
			return decode(cast(dchar[])(buf[0..end]),_pos);
		}
		dstring readUTF8Str(ptrdiff_t len) @trusted
		{
			import std.range;
			import std.array;
			import std.exception : assumeUnique;
			char[] tmp = cast(char[])buf[_pos..$];
			size_t origLen = tmp.length;
			dstring ret = tmp.take(len).array.assumeUnique;
			_pos += origLen - tmp.length;
			return ret;
		}

		dstring readUTF16Str(ptrdiff_t len) @trusted
		{
			import std.range;
			import std.array;
			import std.exception : assumeUnique;
			size_t end = buf.length - buf.length%wchar.sizeof;
			wchar[] tmp = cast(wchar[])buf[_pos..end];
			size_t origLen = tmp.length;
			dstring ret = tmp.take(len).array.assumeUnique;
			_pos += (origLen - tmp.length)*wchar.sizeof;
			return ret;
		}
		dstring readUTF32Str(ptrdiff_t len) @trusted
		{
			import std.range;
			import std.array;
			import std.exception : assumeUnique;
			size_t end = buf.length - buf.length%dchar.sizeof;
			dchar[] tmp = cast(dchar[])buf[_pos..end];
			size_t origLen = tmp.length;
			dstring ret = tmp.take(len).array.assumeUnique;
			_pos += (origLen - tmp.length)*dchar.sizeof;
			return ret;
		}

		void pos(ptrdiff_t v) @property
		{
			_pos = cast(size_t)v;
		}

		ptrdiff_t pos() @property
		{
			return cast(size_t)_pos;
		}

		//Offset from current pos
		void seek(ptrdiff_t v)
		{
			_pos += v;
		}
		void size(ptrdiff_t v) @property { resize(v); }
		ptrdiff_t size() @trusted @property { return buf.length; }

		__gshared NativeDilClass!IDilBlobReader dilClass = new NativeDilClass!IDilBlobReader;

		DilInst toDilInstance() @trusted
		{
			return constructNativeInst!IDilBlobReader(this,dilClass);
		}
	}

	final class DilBlobWriter : IDilBlobWriter
	{
		size_t _pos = 0;

		void putVal(T)(T v) @trusted
		{
			import std.bitmanip : nativeToLittleEndian;
			size_t crnt = _pos;
			_pos += T.sizeof;

			if(_pos > size)
				size = _pos;
			
			(cast(ubyte[])(buf[crnt.._pos]))[0..T.sizeof] = v.nativeToLittleEndian;
		}

		void putUByte(ubyte v)
		{
			putVal(v);
		}
		void putByte(byte v)
		{
			putVal(v);
		}
		void putUShort(ushort v)
		{
			putVal(v);
		}
		void putShort(short v)
		{
			putVal(v);
		}
		void putUInt(uint v)
		{
			putVal(v);
		}
		void putInt(int v)
		{
			putVal(v);
		}
		void putULong(ulong v)
		{
			putVal(v);
		}
		void putLong(long v)
		{
			putVal(v);
		}
		void putUTF8Char(dchar c) @trusted
		{
			import std.utf : encode;
			char[4] tmpBuf;
			size_t tmp = _pos;
			size_t len = encode(tmpBuf,c);
			_pos += len;

			if(_pos > size)
				size = _pos;

			(cast(ubyte[])(buf[tmp.._pos]))[0..len] = cast(ubyte[]) tmpBuf[0..len];
		}
		void putUTF16Char(dchar c) @trusted
		{
			import std.utf : encode;
			wchar[2] tmpBuf;
			size_t tmp = _pos;
			size_t len = encode(tmpBuf,c)*wchar.sizeof;
			_pos += len;

			if(_pos > size)
				size = _pos;

			(cast(ubyte[])(buf[tmp.._pos]))[0..len] = (cast(ubyte[]) tmpBuf)[0..len];
		}
		void putUTF32Char(dchar c)
		{
			putVal(c);
		}
		void putUTF8Str(dstring s)
		{
			foreach(c; s)
				putUTF8Char(c);
		}
		void putUTF16Str(dstring s)
		{
			foreach(c; s)
				putUTF16Char(c);
		}
		void putUTF32Str(dstring s)
		{
			foreach(c; s)
				putUTF32Char(c);
		}

		void pos(ptrdiff_t v) @property
		{
			_pos = cast(size_t)v;
		}

		ptrdiff_t pos() @property
		{
			return cast(size_t)_pos;
		}

		//Offset from current pos
		void seek(ptrdiff_t v)
		{
			_pos += v;
		}

		void size(ptrdiff_t v) @property { resize(v); }
		ptrdiff_t size() @trusted @property { return buf.length; }

		__gshared NativeDilClass!IDilBlobWriter dilClass = new NativeDilClass!IDilBlobWriter;

		DilInst toDilInstance() @trusted
		{
			return constructNativeInst!IDilBlobWriter(this,dilClass);
		}
	}

	T readVal(T)() @trusted
	{
		import std.bitmanip : littleEndianToNative;
		ptrdiff_t crnt = _pos;
		_pos += T.sizeof;

		return (cast(ubyte[])(buf[crnt.._pos]))[0..T.sizeof].littleEndianToNative!(T,T.sizeof);
	}

	ubyte readUByte()
	{
		return readVal!ubyte;
	}
	byte readByte()
	{
		return readVal!byte;
	}
	ushort readUShort()
	{
		return readVal!ushort;
	}
	short readShort()
	{
		return readVal!short;
	}
	uint readUInt()
	{
		return readVal!uint;
	}
	int readInt()
	{
		return readVal!int;
	}
	ulong readULong()
	{
		return readVal!ulong;
	}
	long readLong()
	{
		return readVal!long;
	}
	dchar readUTF8Char() @trusted
	{
		import std.utf : decode;
		return decode(cast(char[])(buf[]),_pos);
	}
	dchar readUTF16Char() @trusted
	{
		import std.utf : decode;
		size_t end = size - size%wchar.sizeof;
		return decode(cast(wchar[])(buf[0..end]),_pos);
	}
	dchar readUTF32Char() @trusted
	{
		import std.utf : decode;
		size_t end = size - size%dchar.sizeof;
		return decode(cast(dchar[])(buf[0..end]),_pos);
	}
	dstring readUTF8Str(ptrdiff_t len) @trusted
	{
		import std.range;
		import std.array;
		import std.exception : assumeUnique;
		char[] tmp = cast(char[])buf[_pos..$];
		size_t origLen = tmp.length;
		dstring ret = tmp.take(len).array.assumeUnique;
		_pos += origLen - tmp.length;
		return ret;
	}

	dstring readUTF16Str(ptrdiff_t len) @trusted
	{
		import std.range;
		import std.array;
		import std.exception : assumeUnique;
		size_t end = buf.length - buf.length%wchar.sizeof;
		wchar[] tmp = cast(wchar[])buf[_pos..end];
		size_t origLen = tmp.length;
		dstring ret = tmp.take(len).array.assumeUnique;
		_pos += (origLen - tmp.length)*wchar.sizeof;
		return ret;
	}
	dstring readUTF32Str(ptrdiff_t len) @trusted
	{
		import std.range;
		import std.array;
		import std.exception : assumeUnique;
		size_t end = buf.length - buf.length%dchar.sizeof;
		dchar[] tmp = cast(dchar[])buf[_pos..end];
		size_t origLen = tmp.length;
		dstring ret = tmp.take(len).array.assumeUnique;
		_pos += (origLen - tmp.length)*dchar.sizeof;
		return ret;
	}

	void putVal(T)(T v) @trusted
	{
		import std.bitmanip : nativeToLittleEndian;
		size_t crnt = _pos;
		_pos += T.sizeof;

		if(_pos > size)
			size = _pos;
		
		(cast(ubyte[])(buf[crnt.._pos]))[0..T.sizeof] = v.nativeToLittleEndian;
	}

	void putUByte(ubyte v)
	{
		putVal(v);
	}
	void putByte(byte v)
	{
		putVal(v);
	}
	void putUShort(ushort v)
	{
		putVal(v);
	}
	void putShort(short v)
	{
		putVal(v);
	}
	void putUInt(uint v)
	{
		putVal(v);
	}
	void putInt(int v)
	{
		putVal(v);
	}
	void putULong(ulong v)
	{
		putVal(v);
	}
	void putLong(long v)
	{
		putVal(v);
	}
	void putUTF8Char(dchar c) @trusted
	{
		import std.utf : encode;
		char[4] tmpBuf;
		size_t tmp = _pos;
		size_t len = encode(tmpBuf,c);
		_pos += len;

		if(_pos > size)
			size = _pos;

		(cast(ubyte[])(buf[tmp.._pos]))[0..len] = cast(ubyte[]) tmpBuf[0..len];
	}
	void putUTF16Char(dchar c) @trusted
	{
		import std.utf : encode;
		wchar[2] tmpBuf;
		size_t tmp = _pos;
		size_t len = encode(tmpBuf,c)*wchar.sizeof;
		_pos += len;

		if(_pos > size)
			size = _pos;

		(cast(ubyte[])(buf[tmp.._pos]))[0..len] = (cast(ubyte[]) tmpBuf)[0..len];
	}
	void putUTF32Char(dchar c)
	{
		putVal(c);
	}
	void putUTF8Str(dstring s)
	{
		foreach(c; s)
			putUTF8Char(c);
	}
	void putUTF16Str(dstring s)
	{
		foreach(c; s)
			putUTF16Char(c);
	}
	void putUTF32Str(dstring s)
	{
		foreach(c; s)
			putUTF32Char(c);
	}

	void resize(ptrdiff_t newSz) @trusted
	{
		Allocator.instance.dispose(buf);
		buf = Allocator.instance.make!MmFile(filename,MmFile.Mode.readWrite,cast(size_t)newSz,null);
	}

	void pos(ptrdiff_t v) @property
	{
		_pos = cast(size_t)v;
	}

	ptrdiff_t pos() @property
	{
		return cast(size_t)_pos;
	}

	//Offset from current pos
	void seek(ptrdiff_t v)
	{
		_pos += v;
	}

	void size(ptrdiff_t v) @property { resize(v); }
	ptrdiff_t size() @trusted @property { return buf.length; }

	IDilBlobReader newReader() { return new DilBlobReader; }
	IDilBlobWriter newWriter() { return new DilBlobWriter; }

	__gshared NativeDilClass!IDilBlob dilClass = new NativeDilClass!IDilBlob;

	shared static this()
	{
		dilClass.addCtor(
			"openReadWrite",
			delegate IDilBlob(DilVal[] args...) @safe
			{
				dilEnforce!DilException(args.length == 1, "Ctor 'openReadWrite' expects one arg.");
				return new DefDilFile(args[0].get!string,MmFile.Mode.readWrite);
			}
		);

		dilClass.addCtor(
			"openReadWriteNew",
			delegate IDilBlob(DilVal[] args...) @safe
			{
				dilEnforce!DilException(args.length == 2, "Ctor 'openReadWriteNew' expects 2 args.");
				return new DefDilFile(args[0].get!string,MmFile.Mode.readWriteNew,cast(size_t)args[1]);
			}
		);
	}

	void close()
	{
		if(buf !is null)
			Allocator.instance.dispose(buf);
	}

	~this()
	{
		close();
	}

	DilInst toDilInstance() @trusted
	{
		return constructNativeInst!IDilBlob(this,dilClass);
	}
}