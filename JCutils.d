import orange.util.Reflection : nameOfFieldAt;
import std.range : lockstep, isArray, ElementType;
import std.conv : to;
import std.string : chompPrefix;

//polar method to generate normal variable, mean 0 variance 1
//ignores half the guesses, memory would make it
//thread unsafe????
double normal() {
	double u,v,s;
	do {
		u = uniform(-1f,1f);
		v = uniform(-1f,1f);
		s = u*u + v*v;
	} while(s==0 || s>1);
	return(u*sqrt(-2*log(s)/s));
}

auto class_arr_dup(T)(T[] array) {
    T[] res = new T[array.length]; 
    foreach(el_old, ref el_new; lockstep(array,res)) {
        el_new = new T(el_old);
    }
    return res;
}

auto class_arr_dup_mt(T)(T[] array) {
    T[] res = new T[array.length];
    foreach(el_old, ref el_new; taskPool.parallel(lockstep(array,res))) {
        el_new = new T(el_old);
    }
    return res;
}

//could perhaps make this multithreaded for really long arrays?
//can't get it to compile when multi-threaded...
void arr_cp_recursive(T,U)(in T input, U output, in bool mt = true) {
	assert(input.length != 0 && input.length == output.length);
	
	static if(isArray!(ElementType!T)) {
		if(mt == true)
			foreach(el_in, ref el_out; lockstep(input, output)) //should be parallel here
				arr_cp_recursive(el_in, el_out, false);
		else
			foreach(el_in, ref el_out; lockstep(input, output))
				arr_cp_recursive(el_in, el_out, false);
	}
	else {
		output[] = input[];
	}
}

//get's the core data type of any array, no matter how many dimensions
//If it can't find an element type at any particular level, it will return the element type at the depth so far
//e.g. ElementTypeRecursive!int == int   and    ElementTypeRecursive!(int[][string][]) == int[][string]
template ElementTypeRecursive (T) {
	static if(is(ElementType!T == void))
		alias T ElementTypeRecursive;
	else static if(is(ElementType!(ElementType!T) == void))
		alias ElementType!T ElementTypeRecursive;
	else
		alias ElementTypeRecursive!(ElementType!T) ElementTypeRecursive;
}

//find how many dimensions an array has.
//doesn't work with associative arrays
template NumDimensions (T) {
	static assert(!__traits(isAssociativeArray, T),"NumDimensions does not work with associative arrays");
	static if(is(ElementType!T == void))
		const NumDimensions = 0;
	else
		const NumDimensions = 1 + NumDimensions!(ElementType!T);
}

template DimensionsString (T) {
	const DimensionsString = chompPrefix(T.stringof, ElementTypeRecursive!T.stringof);
}

//Take T[][][] and turn it into T[length][][][]
//or T[][7][string] to T[length][][7][string]
template InsertFirstDimension (T, size_t length = 0) {
	mixin("alias " ~ (ElementTypeRecursive!T).stringof ~ "[" ~ to!string(length) ~ "]" 
		  ~ DimensionsString!T ~ " InsertFirstDimension;");
}

//Repeats string "s" size_t "num" times at compile-time
template RepeatString (string s, size_t num) {
	static if(num == 0)
		const RepeatString = "";
	else
		const RepeatString = s ~ RepeatString!(s, num-1);
}

//I didn't like having __traits(keyWord,argument) all over my code....

//shorthand for getting symbol name as string
template _id(alias a) {
	const _id = __traits(identifier, a);
}

template _is_arithmetic(alias a) {
	const _is_arithmetic = __traits(isArithmetic, a);
}

template _is_integral(alias a) {
	const _is_integral = __traits(isIntegral, a);
}

template _is_floating(alias a) {
	const _is_floating = __traits(isFloating, a);
}

//provides an associative array, by name, of the fields of obj
//that are of type U. Useful for reading in config files or for
//inspection of variables. 
//Possible future: provide a function that returns all of the
//fields. In a tuple? A class/struct?
auto string_access(U,T)(ref T obj) {
	U[string] dict;
	mixin(dictString!(T, U, "obj"));
	return(dict);
}

/*
mixin template Object_dict(T, string name) {
	TypeOfField!(T,nameOfFieldAt!(T,0))[string] dict;
}
*/

//initialiser for dictStringImpl
template dictString (T, U , string name) {
	const dictString = dictStringImpl!(T, U, name, 0);
}

//Fun, fun, fun! recursive templates generate the (reference) assignments of
//aggregate members to the associative array as a code string.
template dictStringImpl (T, U, string name, size_t i) {
	static if(T.tupleof.length == 0)
		const dictStringImpl = "";
	else static if(T.tupleof.length -1 == i) {
		static if(is(typeof(T.tupleof[i]) == U))
			const dictStringImpl = "dict[\"" ~ nameOfFieldAt!(T,i)
						~ "\"] = " ~ name ~ "." 
						~ nameOfFieldAt!(T,i) ~ ";";
		else 
			const dictStringImpl = "";
	}
	else {
		static if(is(typeof(T.tupleof[i]) == U))
			const dictStringImpl = "dict[\"" ~ nameOfFieldAt!(T,i) 
						~ "\"] = " ~ name ~ "." 
						~ nameOfFieldAt!(T,i) ~ ";\n" 
						~ dictStringImpl!(T, U, name, i+1);
		else
			const dictStringImpl = dictStringImpl!(T, U, name, i+1);
	}
}
