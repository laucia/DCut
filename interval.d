/**
 * interval.d
 * Manipulation of intervals
 *
 * Date : December 16, 2013
 * Authors: Lauris Jullien, lauris.jullien@telecom-paristech.org
 * License: use freely for any purpose
 */
module interval;

import std.algorithm;
import std.conv;
import std.format, std.regex, std.string;
import std.typecons;


/**
 * Class to represent the intervals
 *
 * Simple 2 coordinates tuple
 *
 */
alias Tuple!(ulong,ulong) Interval;

/**
 * Exception thrown when an argument could not be parsed
 *
 */
class ParsingException : Exception {
	this (string msg) {
	    super(msg) ;
	}
}

/**
 * Merge smartly the intervals in the array so that {1,2} and {2,3} 
 * become {1,3}.
 * May change the input array by sorting it.
 *
 * Return:
 *     a sorted and merged array of interval objects
 *
 */
Interval[] mergeIntervals(ref Interval[] intervals){
	// guard
	if(intervals.length == 0){
		return intervals;
	}

	// sort intervals
	sort!("a[0] < b[0]")(intervals);
	
	Interval[] stack;
	stack.reserve(intervals.length);
	stack ~= intervals[0];
	
	Interval top; // temp value for the foreach loop
	foreach(interval;intervals){
		top = stack[$-1];
		if(top[1]+1 < interval[0]){ // +1 because the boundary are included
			stack ~= interval;
		} else if(top[1]+1 <= interval[1]){ // ditto
			top[1] = interval[1];
			stack[$-1] = top;
		}
	}

	return stack;
}

/**
 * Inverse the intervals: returns a list of intervals complementary to the
 * given list
 *
 * Returns:
 *     the complementary intervals array
 *
 */
Interval[] inverseIntervals(ref Interval[] intervals){
	// guard
	if(intervals.length == 0){
		return intervals;
	}

	Interval[] stack;
	stack.reserve(intervals.length + 2);

	// Create a leading interval if needed
	ulong previous = intervals[0][0];
	if (previous != 1){
		stack ~= Interval(1,previous-1);
	}

	// go through all the intervals
	previous = intervals[0][1];
	for(auto i = 1; i < intervals.length; ++i){
		stack ~= Interval(previous + 1, intervals[i][0]-1);
		previous = intervals[i][1];
	}

	// add final interval from the last boundary to the maximum possible one
	stack ~= Interval(previous+1, ulong.max);

	return stack;
}

/**
 * Parse the interval argument from command line and return them as
 * Interval objects. The synthax and result are made to match the 
 * linux cut command as closely as possible, except for reverse intervals that
 * are explicitly forbidden.
 * In the original cut, they were ignored.
 *
 * Params:
 *     arg = argument to be parsed
 * Returns:
 *     an array of Interval objects
 * Throws:
 *     ParsingException if the input is not a string representing intervals
 */
Interval[] parseArgument(string arg){
	// Check if argument is in the correct form
	if(!match(arg, r"^\d+(\-\d+)?(,\d+(\-\d+)?)*$")){
		throw new ParsingException(
			format(
				"The argument \"%s\" is incorrectly formatted.",
				arg));
	}

	// Parse the string interval
	string[] parts = split(arg,",");
	Interval[] intervals;
	intervals.reserve(parts.length);

	string[] temp_string; // temp value for the for loop
	ulong temp_1,temp_2; // temp value for the for loop
	foreach(part; parts){
		if(match(part, r"^\d+\-\d+")){
			temp_string = split(part,"-");
			temp_1 = to!ulong(temp_string[0]);
			temp_2 = to!ulong(temp_string[1]);
			if(temp_1 > temp_2){
				throw new ParsingException(
					format(
						"The interval %s-%s is in reverse order",
						temp_1,temp_2));
			}
			intervals ~= Interval(
				temp_1,
				temp_2
				);
		} else {
			temp_1 = to!ulong(part);
			intervals ~=  Interval(
				temp_1,
				temp_1
				);
		}
	}

	return mergeIntervals(intervals);
} 

/+ -------------------------------------------------------------------------
 +     Unittests
 + ------------------------------------------------------------------------- +/

// mergeIntervals tests
// --------------------
// Test that the affirmation in the function description is true
private unittest{
	Interval[] intervals = [Interval(1,2),Interval(2,3)];
	assert(mergeIntervals(intervals) == [Interval(1,3)]);
}

// inverseIntervals tests:
// -----------------------
// test that a given interval is correctly transformed into it's complementary
private unittest{
	Interval[] intervals = [
		Interval(2,4),
		Interval(6,9),
		Interval(12,16)];

	assert(inverseIntervals(intervals)==[
		Interval(1,1),
		Interval(5,5),
		Interval(10,11),
		Interval(17,ulong.max)]);
}

// parseArgument tests
// -------------------
// Test that incorrect values are recognized and throw an error
private unittest{
	try{
		parseArgument("test");
		assert(false);
	} catch (ParsingException e){
		assert(true);
	}
	try{
		parseArgument("1,2-,3");
		assert(false);
	} catch (ParsingException e){
		assert(true);
	}
	try{
		parseArgument("1,4-2,3");
		assert(false);
	} catch (ParsingException e){
		assert(true);
	}
}

/// Test that intervals are correctly recognized in the linux cut program sens
private unittest {
	Interval[] intervals = [
		Interval(1,2),
		Interval(4,4),
		Interval(6,9),
		Interval(11,16)];
	assert(parseArgument("1,6-8,7-9,2,11-13,4,13-16") == intervals);
}