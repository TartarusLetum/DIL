module dil.std.time;

import dil.val;
import dil.exception;
import dil.meta;

DilVal std_time_dil_module_fnc()(dstring dir) @trusted
{
	import core.time;
	import std.datetime : Clock;
	DilTable tbl = new DilTable;

	tbl[DilVal("StopWatch"d)] = DilVal(DilStopWatch.dilClass);

	tbl[DilVal("nsecsDurString"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		return DilVal(args[0].get!ptrdiff_t.dur!"nsecs".toString);
	}));

	tbl[DilVal("hnsecsDurString"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		return DilVal(args[0].get!ptrdiff_t.dur!"hnsecs".toString);
	}));

	tbl[DilVal("secsDurString"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		return DilVal(args[0].get!ptrdiff_t.dur!"seconds".toString);
	}));

	tbl[DilVal("currStdTime"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		return DilVal(Clock.currStdTime());
	}));

	tbl[DilVal("benchmark"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted {
		import std.datetime.stopwatch;
		StopWatch sw;
		sw.start;
		ptrdiff_t iters = args[0].get!ptrdiff_t;
		IDilCallable callable = args[1].get!IDilCallable;

		Duration dur = Duration.zero;
		for(ptrdiff_t n = 0; n < iters; n++)
		{
			sw.reset;
			callable.call(args[2..$]);
			dur += sw.peek;
		}
		return DilVal((dur/iters).total!"nsecs");
	}));

	return DilVal(tbl);
}

interface IDilStopWatch
{
	void start();
	void stop();
	void reset();
	bool running() @property;
	ptrdiff_t total() @property;
}

final class DilStopWatch : IDilStopWatch
{
	import std.datetime.stopwatch;
	StopWatch sw;

	void start() { sw.start(); }
	void stop() { sw.stop(); }
	void reset() { sw.reset(); }
	bool running() @property { return sw.running; }
	ptrdiff_t total() @property { return cast(ptrdiff_t) sw.peek.total!"nsecs"; }

	__gshared NativeDilClass!IDilStopWatch dilClass = new NativeDilClass!IDilStopWatch;

	shared static this()
	{
		dilClass.addCtor(
			"new",
			delegate IDilStopWatch(DilVal[] args...) @safe
			{
				return new DilStopWatch;
			}
		);
	}
}