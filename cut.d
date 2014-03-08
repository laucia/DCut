/**
 * cut.d
 * A reduced functionality version of the Linux command line tool cut
 *
 * Date : December 16, 2013
 * Authors: Lauris Jullien, lauris.jullien@telecom-paristech.org
 * License: use freely for any purpose
 */

import std.conv;
import std.getopt;
import std.stdio;
import std.string;

import lineprocessors;
import interval:ParsingException;

/// print help and usage informations
void printHelp(){
	writeln(q{
		usage: cut -b list [--complement] [file ...]
		       cut -f list [--complement -d delim] [file ...]
		options:
		    -b: output the specified bytes of each line of the files
		    -f: output the specified delimited fields of each line from files
		    -d: specify the field delimiter (default=TAB)
		    --complement: invert the selection

		    --help -h:    print this help
		    --verbose -v: print some informations about the command entered
	}.outdent());
}

void main(string[] args) {
	// declare/init parameters
	string delimiter = to!string(to!char(9)); // default delimiter to tab
	string byteOption;
	string fields;
	bool complement = false;
	bool verbose = false;
	bool help = false;

	// parse options
	try{
		getopt(
			args,
			"d" , &delimiter,
			"b", &byteOption,
			"f", &fields,
			"complement", &complement,
			"verbose|v", &verbose,
			"help|h", &help);
	} catch(Exception e){
		stderr.writeln(e.msg);
		printHelp();
		return;
	}

	// check that the options are valid or help as been asked
	if(help || ( !byteOption && !fields) || (byteOption && fields)){
		printHelp();
		return;
	}

	// Print getops argument parsing
	if(verbose) {
		writeln("options::");
		writefln("\tdelimiter:\t\t%s",delimiter);
		if(byteOption) {
			writefln("\tspecified bytes:\t%s", byteOption);
		}
		if(fields) {
			writefln("\tspecified fields:\t%s", fields);
		}
		if(complement) {
			writeln("\tinversed selection");
		}
		writeln("files to cut::");
		writefln("\t%(%s, %)",	args[1..$]);
	}

	// Process the files
	LineProcessor processor;
	try {
		if(byteOption){
			processor = new ByteProcessor(byteOption,complement);
		} else {
			processor = new FieldProcessor(fields,delimiter,complement);
		}
	} catch(ParsingException e){
		stderr.writeln(e.msg);
		printHelp();
		return;
	}
	foreach(filename; args[1..$]){
		processor.readFile(filename);
	}
}