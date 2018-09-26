module dil.std.thread;

import dil.val;
import dil.exception;
import dil.meta;

import core.thread;

DilVal std_thread_dil_module_fnc()(dstring dir) @trusted
{
	DilTable tbl = new DilTable;

	tbl[DilVal("Thread"d)] = DilVal(DilThread.dilClass);

	tbl[DilVal("sleep"d)] = DilVal(new DilDDelegate(delegate DilVal(DilTable context, DilVal[] args...) @trusted{
		dilEnforce!DilException(args.length == 1, "Expecting 1 arg in 'sleep'. There are %s.");
		Thread.sleep((cast(size_t) args[0]).dur!"msecs");
		return DilVal.init;
	}));

	return DilVal(tbl);
}

interface IDilThread  
{
	void start();
	DilVal join();
	bool alive() @property;
	DilVal retVal() @property;
	void retVal(DilVal v) @property;
}

final class DilThread : IDilThread
{
	Thread thrd;
	IDilCallable _callable;
	DilVal[] _args;
	DilVal _retVal = DilVal.init;

	this()(IDilCallable callable, DilVal[] args)
	{
		_callable = callable;
		_args = args;

		thrd = new Thread(&run);
	}

	void run()
	{
		_retVal = _callable.call(_args);
	}

	void start()
	{
		thrd.start();
	}
	DilVal join()
	{
		thrd.join();
		return retVal;
	}

	bool alive() @property { return thrd.isRunning; }

	DilVal retVal() @property
	{
		return _retVal;
	}

	void retVal(DilVal v) @property
	{
		_retVal = v;
	}

	__gshared NativeDilClass!IDilThread dilClass = new NativeDilClass!IDilThread;

	shared static this()
	{
		dilClass.addCtor(
			"new",
			delegate IDilThread(DilVal[] args...) @safe
			{
				dilEnforce!DilException(args.length > 0, "Ctor 'Thread.new' expects at least one argument.");
				return new DilThread(args[0].get!IDilCallable,args[1..$]);
			}
		);

		dilClass.addCtor(
			"start",
			delegate IDilThread(DilVal[] args...) @trusted
			{
				dilEnforce!DilException(args.length > 0, "Ctor 'Thread.start' expects at least one argument.");
				auto thrd = new DilThread(args[0].get!IDilCallable,args[1..$]);
				thrd.start();
				return thrd;
			}
		);
	}
}