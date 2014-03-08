/**
 * lineprocessors.d
 * Objects to process a line of file for the cut program
 *
 * Date : December 16, 2013
 * Authors: Lauris Jullien, lauris.jullien@telecom-paristech.org
 * License: use freely for any purpose
 */

module lineprocessors;

import std.string;
import std.algorithm;
import std.stdio;
import std.file;

import interval;

/**
 * Interface to abstract the basic file reading and only implement the relevent 
 * processing for each line of the file.
 *
 */
interface LineProcessor {


	/**
	 * Process a line of text.
	 *
	 * Params:
	 *     s = line to process
	 *
	 **/
	void processLine(string s);

	/**
	 * Function that read a file and process each of its lines with the
	 * interface's implementation of ``processLine``
	 * 
	 * Params:
	 *     filename = name of the file to process
	 *
	 */
	final void readFile(string filename){
		// Check if the fill exist
		if(! std.file.exists(filename)) {
			stderr.writefln(
				"file \"%s\" does not exist. Check your path",
				filename);
			return;
		}

		File f = File(filename,"r");
		while(!f.eof()) {
			processLine(chop(f.readln()));
		}
		f.close();
	}
}


/**
 * Simple echo line processor.
 * behave like linux's cat command.
 *
 */
class CatProcessor : LineProcessor {
	void processLine(string s){
		writeln(s);
	}
}

/+ ------------------------------- README ----------------------------------

	The two line processors below print directly to td out is done to avoid 
	constructing an extra string or buffer and then print its contents.

	A consequence of that choice is that unittest code to test the 
	processLine function need to redirect stdout. Documentation indicates that 
	it can be done into a file.
	Tests that do so in order to check processLine output are at the end of the 
	document but portability accros OS might be a problem.

   ------------------------------------------------------------------------- +/

/**
 * Process a line by dividing it according to a given delimiter, and printing
 * to stdout the thus defined fields specified by an input argument.
 *
 */
class FieldProcessor : LineProcessor {
	/// The parts that should be displayed
	Interval[] intervals;
	
	/// Delimiter string used to split into field and rejoin strings
	string delimiter;

	/**
	 * Constructor
	 *
	 * Params:
	 *     arg: a string representation of the intervals of fields to display
	 *     delimiter: element that define the boundary of fields
	 *     complement: true if the given intervals are not to be displayed 
	 *                 instead of displayed
	 * Throws:
 	 *     ParsingException if the input is not a string representing intervals
	 */
	this(string arg, string delimiter, bool complement){
		this.intervals = parseArgument(arg);
		if(complement){
			this.intervals = inverseIntervals(this.intervals);
		}
		this.delimiter = delimiter;
	}

	void processLine(string s){

		// If we can't find the delimiter, print the line, like the linux cut
		if(!canFind(s,this.delimiter)){
			if(s.length > 0){
				writeln(s);
			}
			return;
		}

		string[] splits = split(s,this.delimiter);
		ulong begin,end;
		auto sliptLength = splits.length;
		Interval first = this.intervals[0];
		if(sliptLength > 0){
			foreach(interval; this.intervals){
				// do not consider intervals that do not describe data 
				if(interval[0] > sliptLength){
					break;
				}

				// compute the split boundary from interval
				begin = max(interval[0] - 1,0);
				end = min(interval[1],sliptLength);

				// add delimiter if needed
				if(interval != first){
					write(this.delimiter);
				}

				// write split 
				write(join(
					splits[begin..end],
					this.delimiter));
			}
			writeln();
		}
	}
}

/**
 * Process line and display only specified byte positions
 *
 */
class ByteProcessor : LineProcessor{
	///The parts that should be displayed
	Interval[] intervals;

	/**
	 * Constructor
	 *
	 * Params:
	 *     arg: a string representation of the intervals of bytes to display
	 *     complement: true if the given intervals are not to be displayed 
	 *                 instead of displayed
	 * Throws:
 	 *     ParsingException if the input is not a string representing intervals
	 */
	this(string arg, bool complement){
		this.intervals = parseArgument(arg);
		if(complement){
			this.intervals = inverseIntervals(this.intervals);
		}
	}

	void processLine(string s){
		/*  as string is an immutable char[] and byte and char have the same 
		    size we can consider that byte positions and string positions are 
		    equivalent.
		    Multi-byte characters might be splitted that way. */
		ulong begin,end;
		auto stringLength = s.length;
		if(stringLength > 0){
			foreach(interval; this.intervals){
				// do not consider intervals that do not describe data 
				if(interval[0] > stringLength){
					break;
				}

				// compute the split boundary from interval
				begin = max(interval[0] - 1,0);
				end = min(interval[1],stringLength);
				
				// write split 
				writef("%-(%s%)",s[begin..end]);
			}
			writeln();
		}
	}
}



/+ -------------------------------------------------------------------------
 +     Unittests
 + ------------------------------------------------------------------------- +/

version(unittest) {
	import std.path, std.range;
}

private unittest {
	// Create a temporary file and set stdout to write in this file
	string tempFilePath = buildPath(tempDir(),"cut_test");
	auto original = stdout;
	try{
		stdout.open(tempFilePath,"w");
	} catch(FileException e){
		writeln(e.msg);
		return;
	}
	
	// Test elements and write results
	LineProcessor processor;
	string test_string = "1:2:3:4:5:6:7:8:9:10:11:12";
	string solution[];


	// FieldProcessor tests
	// --------------------
	processor = new FieldProcessor("1-2,4,7-9",":", false);
	processor.processLine(test_string);
	solution ~= "1:2:4:7:8:9";
	processor.processLine("No delimiter here");
	solution ~= "No delimiter here";
	processor = new FieldProcessor("1-2,4,7-9",":", true);
	processor.processLine(test_string);
	solution ~= "3:5:6:10:11:12";

	// ByteProcessor tests
	// -------------------
	processor = new ByteProcessor("1-4,8-10,12",false);
	processor.processLine(test_string);
	solution ~= "1:2::5::";
	processor = new ByteProcessor("1-4,8-10,12",true);
	processor.processLine(test_string);
	solution ~= "3:467:8:9:10:11:12";


	// reset stdout in its original config
	stdout.close();
	stdout = original;
	
	// re-read file and validate response
	File f = File(tempFilePath,"r");
	auto lines = f.byLine();
	int count = 0;
	foreach(line; lines.take(solution.length)){
		assert (line == solution[count]);
		count ++;
	}

	// Cleanup
	f.close();
	try{
		std.file.remove(tempFilePath);
	} catch (FileException e){
		// silent failure: temp files should hopefully be removed by the OS
	}
}
