import std.stdio;
import dil;
import dil.lib;

void main(string[] args)
{
	import std.getopt;

	auto helpInfo = args.getopt(
		"I", "Add import directory.", &importDirs
	);

	if(helpInfo.helpWanted || args.length == 1)
	{
		defaultGetoptPrinter("Dil Scripting Language Executable.", helpInfo.options);
		return;
	}

	dilTLSScope[DilVal("import"d)] = DilVal(makeDefDilImportCallable());

	import std.file : readText;
	foreach(arg;args[1..$])
		arg.readText.compile(arg).call(null);
}