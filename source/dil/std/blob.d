module dil.std.blob;

import dil.meta;
import dil.val;
import dil.rng;

DilVal std_blob_dil_module_fnc()(dstring dir) @trusted
{
	DilTable tbl = new DilTable;	

	tbl[DilVal("Blob"d)] = DilVal(DilBlob.dilClass);

	tbl[DilVal("utf8Range"d)] = DilVal(makeDilCallable(&utf8Range,"utf8Range"));
	tbl[DilVal("utf16Range"d)] = DilVal(makeDilCallable(&utf16Range,"utf16Range"));
	tbl[DilVal("utf32Range"d)] = DilVal(makeDilCallable(&utf32Range,"utf32Range"));
	tbl[DilVal("ubyteRange"d)] = DilVal(makeDilCallable(&ubyteRange,"ubyteRange"));

	return DilVal(tbl);
}

IDilRng utf8Range(IDilBlobReader reader)
{
	final class CharRange : IDilRng
	{
		size_t pos;
		dchar c;
		bool empty = false;
		DilVal value() @safe @property
		{
			return DilVal(c);
		}
		DilVal key() @safe @property
		{
			return DilVal(pos);
		}
		bool isEmpty() @safe @property
		{
			return empty;	
		}
		void advance() @safe
		{
			if(reader.pos < reader.size)
			{
				pos = reader.pos;
				c = reader.readUTF8Char();
			}
			else
				empty = true;
		}
	}

	auto rng = new CharRange;
	rng.advance;
	return rng;
}

IDilRng utf16Range(IDilBlobReader reader)
{
	final class CharRange : IDilRng
	{
		size_t pos;
		dchar c;
		bool empty = false;
		DilVal value() @safe @property
		{
			return DilVal(c);
		}
		DilVal key() @safe @property
		{
			return DilVal(pos);
		}
		bool isEmpty() @safe @property
		{
			return empty;	
		}
		void advance() @safe
		{
			if(reader.pos < reader.size)
			{
				pos = reader.pos;
				c = reader.readUTF16Char();
			}
			else
				empty = true;
		}
	}

	auto rng = new CharRange;
	rng.advance;
	return rng;
}

IDilRng utf32Range(IDilBlobReader reader)
{
	final class CharRange : IDilRng
	{
		size_t pos;
		dchar c;
		bool empty = false;
		DilVal value() @safe @property
		{
			return DilVal(c);
		}
		DilVal key() @safe @property
		{
			return DilVal(pos);
		}
		bool isEmpty() @safe @property
		{
			return empty;	
		}
		void advance() @safe
		{
			if(reader.pos < reader.size)
			{
				pos = reader.pos;
				c = reader.readUTF32Char();
			}
			else
				empty = true;
		}
	}

	auto rng = new CharRange;
	rng.advance;
	return rng;
}

IDilRng ubyteRange(IDilBlobReader reader)
{
	final class IntRange : IDilRng
	{
		size_t pos;
		ubyte v;
		bool empty = false;
		DilVal value() @safe @property
		{
			return DilVal(v);
		}
		DilVal key() @safe @property
		{
			return DilVal(pos);
		}
		bool isEmpty() @safe @property
		{
			return empty;	
		}
		void advance() @safe
		{
			if(reader.pos < reader.size)
			{
				pos = reader.pos;
				v = reader.readUByte;
			}
			else
				empty = true;
		}
	}

	auto rng = new IntRange;
	rng.advance;
	return rng;
}

interface IDilBlobReader : IDilContextlessConstructable
{
	@safe:
	ubyte readUByte();
	byte readByte();
	ushort readUShort();
	short readShort();
	uint readUInt();
	int readInt();
	ulong readULong();
	long readLong();
	dchar readUTF8Char();
	dchar readUTF16Char();
	dchar readUTF32Char();
	dstring readUTF8Str(ptrdiff_t len);
	dstring readUTF16Str(ptrdiff_t len);
	dstring readUTF32Str(ptrdiff_t len);

	void pos(ptrdiff_t v) @property;
	ptrdiff_t pos() @property;

	//Offset from current pos
	void seek(ptrdiff_t v);

	void size(ptrdiff_t v) @property;
	ptrdiff_t size() @property;
}

interface IDilBlobWriter : IDilContextlessConstructable
{
	@safe:
	void putUByte(ubyte v);
	void putByte(byte v);
	void putUShort(ushort v);
	void putShort(short v);
	void putUInt(uint v);
	void putInt(int v);
	void putULong(ulong v);
	void putLong(long v);
	void putUTF8Char(dchar c);
	void putUTF16Char(dchar c);
	void putUTF32Char(dchar c);
	void putUTF8Str(dstring s);
	void putUTF16Str(dstring s);
	void putUTF32Str(dstring s);

	void pos(ptrdiff_t v) @property;
	ptrdiff_t pos() @property;

	//Offset from current pos
	void seek(ptrdiff_t v);

	void size(ptrdiff_t v) @property;
	ptrdiff_t size() @property;
}

interface IDilBlob : IDilBlobReader, IDilBlobWriter
{
	@safe:
	IDilBlobReader newReader();
	IDilBlobWriter newWriter();
}

final class DilBlob : IDilBlob
{
	ubyte[] buf;
	size_t _pos = 0;

	final class DilBlobReader : IDilBlobReader
	{
		size_t _pos = 0;

		T readVal(T)() @safe
		{
			import std.bitmanip : littleEndianToNative;
			ptrdiff_t crnt = _pos;
			_pos += T.sizeof;

			return buf[crnt.._pos][0..T.sizeof].littleEndianToNative!(T,T.sizeof);
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
		dchar readUTF8Char()
		{
			import std.utf : decode;
			return decode(cast(char[])buf,_pos);
		}
		dchar readUTF16Char()
		{
			import std.utf : decode;
			size_t end = buf.length - buf.length%wchar.sizeof;
			return decode(cast(wchar[])buf[0..end],_pos);
		}
		dchar readUTF32Char()
		{
			import std.utf : decode;
			size_t end = buf.length - buf.length%dchar.sizeof;
			return decode(cast(dchar[])buf[0..end],_pos);
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
		void size(ptrdiff_t v) @property { buf.length = v; }
		ptrdiff_t size() @property { return buf.length; }

		__gshared NativeDilClass!IDilBlobReader dilClass = new NativeDilClass!IDilBlobReader;

		DilInst toDilInstance() @trusted
		{
			return constructNativeInst!IDilBlobReader(this,dilClass);
		}
	}

	final class DilBlobWriter : IDilBlobWriter
	{
		size_t _pos = 0;

		void putVal(T)(T v) @safe
		{
			import std.bitmanip : nativeToLittleEndian;
			size_t crnt = _pos;
			_pos += T.sizeof;

			if(_pos > buf.length)
				buf.length = _pos;
			
			buf[crnt.._pos] = v.nativeToLittleEndian;
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
		void putUTF8Char(dchar c)
		{
			import std.utf : encode;
			char[4] tmpBuf;
			size_t tmp = _pos;
			size_t len = encode(tmpBuf,c);
			_pos += len;

			if(_pos > buf.length)
				buf.length = _pos;

			buf[tmp.._pos] = cast(ubyte[]) tmpBuf[0..len];
		}
		void putUTF16Char(dchar c)
		{
			import std.utf : encode;
			wchar[2] tmpBuf;
			size_t tmp = _pos;
			size_t len = encode(tmpBuf,c)*wchar.sizeof;
			_pos += len;

			if(_pos > buf.length)
				buf.length = _pos;

			buf[tmp.._pos] = (cast(ubyte[])tmpBuf)[0..len];
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

		void size(ptrdiff_t v) @property { buf.length = v; }
		ptrdiff_t size() @property { return buf.length; }

		__gshared NativeDilClass!IDilBlobWriter dilClass = new NativeDilClass!IDilBlobWriter;

		DilInst toDilInstance() @trusted
		{
			return constructNativeInst!IDilBlobWriter(this,dilClass);
		}
	}

	T readVal(T)()
	{
		import std.bitmanip : littleEndianToNative;
		ptrdiff_t crnt = _pos;
		_pos += T.sizeof;

		return buf[crnt.._pos][0..T.sizeof].littleEndianToNative!(T,T.sizeof);
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
	dchar readUTF8Char()
	{
		import std.utf : decode;
		return decode(cast(char[])buf,_pos);
	}
	dchar readUTF16Char()
	{
		import std.utf : decode;
		size_t end = buf.length - buf.length%wchar.sizeof;
		return decode(cast(wchar[])buf[0..end],_pos);
	}
	dchar readUTF32Char()
	{
		import std.utf : decode;
		size_t end = buf.length - buf.length%dchar.sizeof;
		return decode(cast(dchar[])buf[0..end],_pos);
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

	void putVal(T)(T v) @safe
	{
		import std.bitmanip : nativeToLittleEndian;
		size_t crnt = _pos;
		_pos += T.sizeof;

		if(_pos > buf.length)
			buf.length = _pos;
		
		buf[crnt.._pos] = v.nativeToLittleEndian;
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
	void putUTF8Char(dchar c)
	{
		import std.utf : encode;
		char[4] tmpBuf;
		size_t tmp = _pos;
		size_t len = encode(tmpBuf,c);
		_pos += len;

		if(_pos > buf.length)
			buf.length = _pos;

		buf[tmp.._pos] = cast(ubyte[]) tmpBuf[0..len];
	}
	void putUTF16Char(dchar c)
	{
		import std.utf : encode;
		wchar[2] tmpBuf;
		size_t tmp = _pos;
		size_t len = encode(tmpBuf,c)*wchar.sizeof;
		_pos += len;

		if(_pos > buf.length)
			buf.length = _pos;

		buf[tmp.._pos] = (cast(ubyte[]) tmpBuf)[0..len];
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

	void size(ptrdiff_t v) @property { buf.length = v; }
	ptrdiff_t size() @property { return buf.length; }

	IDilBlobReader newReader() { return new DilBlobReader; }
	IDilBlobWriter newWriter() { return new DilBlobWriter; }

	__gshared NativeDilClass!IDilBlob dilClass = new NativeDilClass!IDilBlob;

	shared static this()
	{
		dilClass.addCtor(
			"new",
			delegate IDilBlob(DilVal[] args...) @safe
			{
				return new DilBlob;
			}
		);
		dilClass.addCtor(
			"make",
			delegate IDilBlob(DilVal[] args...) @safe
			{
				DilBlob blob = new DilBlob;
				blob.size = args[0].get!ptrdiff_t;
				return blob;
			}
		);
	}

	DilInst toDilInstance() @trusted
	{
		return constructNativeInst!IDilBlob(this,dilClass);
	}

	override string toString()
	{
		import std.format : format;
		return format!"%s"(buf);
	}
}