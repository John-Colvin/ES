//import orange.util.Reflection : nameOfFieldAt;
import std.range : lockstep, ElementType;
import std.traits : isArray;
import std.conv : to;
import std.string : chompPrefix, cmp;
import std.random : uniform;
import std.algorithm : reduce;
import core.stdc.math;

const nan = double.nan;

auto sum(T) (T range) {
    return reduce!("a + b")(range);
}

auto mean(T)(T arr) {
    return sum(arr) / arr.length;
}
/*
auto ma(T)(T[] a, size_t w, bool nans = false, centered = false) {
    if(nans) {
        auto length = a.length;
        auto start = ;
        auto end = 
    }
    else {
        auto length = a.length - w + 1;
    }
    T[] ret = new T[length];
    
    foreach(i; 0..length) 
        ret[i] = mean(a[i..i+w]);
    
    return ret;
}

unittest
{
    double[] data = [1,2,3,4,5,6,7,8];
    auto width = 4;
    assert(ma(data, width) == [2.5, 3.5, 4.5, 5.5, 6.5]);
}*/


/*
auto randn(distribution = "uniform", size_t dimensions = 1, string boundaries = "[)", T)
            (T a, T b, size_t[] lengths) 
{
    static if(cmp(distribution, "uniform") == 0) {
        mixin("T" ~ RepeatString!("[]",dimensions) ~ " ret = " ~ 
              RepeatString!("[]",dimensions -1) ~ "[lengths[0]];");
        foreach(i; 1..dimensions)
            foreach(ref el; ret)
                mixin("el = new T" ~ ";");
    }
}
*/
auto uniform_(string boundaries = "[)", dimensions , T1, T2)(T1 a, T2 b); 

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

template ArraySizes (sizes...) {
    const ArraySizes = ArraySizesImpl!(0, sizes);
}

template ArraySizesImpl (size_t i, sizes...) {
    static if(i == sizes.length - 1)
        const ArraySizesImpl = "[" ~ to!string(sizes[i]) ~ "]";
    else
        const ArraySizesImpl = "[" ~ to!string(sizes[i]) ~ "]" ~
                               ArraySizesImpl!(sizes, i+1);
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

template _is_arithmetic(T) {
    const _is_arithmetic = __traits(isArithmetic, T);
}

template _is_integral(alias a) {
    const _is_integral = __traits(isIntegral, a);
}

template _is_integral(T) {
    const _is_integral = __traits(isIntegral, T);
}

template _is_floating(alias a) {
    const _is_floating = __traits(isFloating, a);
}

template _is_floating(T) {
    const _is_floating = __traits(isFloating, T);
}


//SURELY, seeing as we know all the member names at compile time, a
//switch statement could be generated....

//wrapper struct for string_access.
//sorts out the pointers.
struct AAof (U) {
    U*[string] field_ptrs;
    this(T)(ref T obj) {
        field_ptrs = string_access!U(obj);
    }
    auto ref opIndex(S : string)(S field) {
        return *(field_ptrs[field]);
    }
}

//provides an associative array, by name, of pointers to the fields of obj
//that are of type U. Useful for reading in config files or for
//inspection of variables. 
//Possible future: provide a function that returns all of the
//fields. In a tuple? A class/struct?
auto string_access(U,T)(ref T obj) {
    U*[string] dict;
    mixin(dictString!(T, U, "obj"));
    dict.rehash;
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
                        ~ "\"] = &" ~ name ~ "." 
                        ~ nameOfFieldAt!(T,i) ~ ";";
        else 
            const dictStringImpl = "";
    }
    else {
        static if(is(typeof(T.tupleof[i]) == U))
            const dictStringImpl = "dict[\"" ~ nameOfFieldAt!(T,i) 
                        ~ "\"] = &" ~ name ~ "." 
                        ~ nameOfFieldAt!(T,i) ~ ";\n" 
                        ~ dictStringImpl!(T, U, name, i+1);
        else
            const dictStringImpl = dictStringImpl!(T, U, name, i+1);
    }
}

//Stolen from orange, For some reason it has all sorts of problems linking.
template nameOfFieldAt (T, size_t position)
{
    static assert (position < T.tupleof.length, format!(`The given position "`, position, `" is greater than the number of fields (`, T.tupleof.length, `) in the type "`, T, `"`));
    
static if (T.tupleof[position].stringof.length > T.stringof.length + 3)
const nameOfFieldAt = T.tupleof[position].stringof[1 + T.stringof.length + 2 .. $];

else
const nameOfFieldAt = "";
}
