import problem;
import std.random : uniform;
import std.range : lockstep;
import orange.Reflection : nameOfFieldAt;

auto sum = reduce!("a + b");

//be prepared for a mess if this becomes a class...parameters are expected
//to be moved by value!
struct Parameter(T, U) {
	T value;
	alias value this;
	U mutability;
	
	this(T value, U mutability) {
		this.value = value;
		this.mutability = mutability;
	}
}

//To be templated with user-defined parameters class.
struct Init_params(T) {
	mixin(gen_fields!T);
}

template gen_fields(T) {
	const gen_fields = gen_fieldsImpl!(T, 0);
}

template gen_fieldsImpl(T, size_t i) {
	static if(T.tupleof.length == 0)
		const gen_fieldsImpl = "";
	else static if(T.tupleof.length -1 == i) {
		const gen_fieldsImpl = InsertFirstDimension!(T.tupleof[i], 2).stringof
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_range;\n" ~
						 InsertFirstDimension!(T.tupleof[i], 2).stringof 
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_mut_range;";
	}
	else {
		const gen_fieldsImpl = InsertFirstDimension!(T.tupleof[i], 2).stringof 
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_range;\n" ~ 
						 InsertFirstDimension!(T.tupleof[i], 2).stringof 
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_mut_range;\n" ~ 
						 gen_fieldsImpl!(T, i+1);
	}
}

//currently only works with one type at a time.
void read_cfg(U,T)(ref T params, string filename) {
	Node root = Loader(filename).load();
	Node solution = root["solution"];

	auto link = string_access!(U)(params);
	
	int i=0; //has to be outside because solution is a tuple???
	foreach(Node set; solution) {
		foreach(string name, Node value; set) {
			link[name~"_range"][i][0] = value["min"].as!U;
			link[name~"_range"][i][1] = value["max"].as!U;
			link[name~"_mut_range"][i][0] = value["mut_min"].as!U;
			link[name~"_mut_range"][i][1] = value["mut_max"].as!U;
		}
		++i;
	}
}

//no support for any params with higher dimension than 1.

//please inherit from this and override anything you want to change
//in order specify the meaning of addition, division etc. on your
//parameters. Also, overriding mutate allows you to implement any
//different mutation style you want. You could even make this in to
//a basic whole population crossover GA by overriding mutate and average.

//please bare in mind that integer fields will be mutated. The meaning 
//of the integer values should be somehow ordered otherwise small 
//mutations could lead to drastic changes.

//could i have some form of default system where if an add operation
//is implemented for the parameters then use that one etc...?

class Solution (T){
	T params;
	int id;
	double fitness;
	Problem!Solution problem;

	this(T params) {
		this.params = params;
	}
	
	//full constructor including solution initialisation
	//has to be a template to work around a bug in D
	//mutabilities initialised to uniform. Is this right? It's gonna cause
	//problems with array parameters...
	this(U=bool)(Problem!Solution problem, Init_params init_params, int id) {
		this.problem = problem;
		this.id = id;
		//leave fitness as nan
		
		static if(__traits(hasMember, T, "init");
			params.init(init_params);
		else {
			auto link = string_access!(double[2])(params);
			foreach(uint i, ref param; params.tupleof) {
				auto name = param.stringof;
				param = uniform!"[]"(link[name~"_range"][0],link[name~"_range"][1]);
				param.mutability = uniform!"[]"(link[name~"_mut_range"][0],link[name~"_mut_range"][1]);	
			}
		}
	}
	
	//basic constructor for a blank sine_fit. All params initialised to 0
	//has to be template to overcome bug in d
	this(U=bool)() {
		params = T.blank();
		id = -1;
        fitness = double.nan;
        //problem left uninitialised. Is this ok?
	}
	
	//copy constructor. Again, has to be a bloody template.....
    this(U=bool)(Solution a) {
		params = a.params;
		id = a.id;
		fitness = a.fitness;
		prob = a.prob;
    }
	
	//reroute for constructor from Population
	//exands args to main constructor.
	this(U...)(int id, U args) {
		this(args[0], args[1], id);
	}
	
	void evaluate() {
		fitness = problem.fitness_calc(derived_object);
	}
	
	void mutate(Solution parent) {
		id = parent.id;
		foreach(uint i, ref param; params.tupleof) {
			//should user defined types which possess the right 
			//operator primitives be allowed here?
			static assert(!_is_arithmetic!param, "No default mutation \
				implementation for non-arithmetic types");
			static if(_is_arr!param) {
				double[] mut_vect = new double[parent.params.tupleof.length];
				foreach(ref mut; mut_vect) {
					mut = normal();
				}
				param[] = parent.params.tupleof[i][] + mut[]*parent.params.tupleof[i].mutability[];
			}
			else {
				param = parent.params.tupleof[i] + normal()*parent.params.tupleof[i].mutability;
			}
		}
	}
	
	auto opOpAssign(string op, T)(T rhs) {
		static if(!(op == '*' || op == '/')
			static assert("operation: " ~op~ " not supported");
		foreach(uint i, ref param; params.tupleof)
			static if(_is_arr!param)
				static if(_is_arr!rhs)
					mixin("param[] " ~ op ~"= rhs[];");
				else
					mixin("param[] " ~ op ~"= rhs;");
			else
				mixin("param " ~ op ~ "= rhs;");
		return this;
	}

	auto opOpAssign(string op, U:T)(U rhs) {
		foreach(uint i, ref param; params.tupleof)
			static if(_is_arr!param)
				mixin("param[] " ~ op ~"= rhs.params.tupleof[i][];");
			else
				mixin("param " ~ op ~ "= rhs.params.tupleof[i];");
		return this;
	}

	auto opBinary(string op, U:T)(U rhs) {
		U tmp = new U;
		foreach(uint i, ref param; tmp.params.tupleof)
			static if(_is_arr!param)
				mixin("param[] = this.params.tupleof[i][] " ~ op ~ " rhs.params.tupleof[i][];");
			else
				mixin("param = this.params.tupleof[i] " ~ op ~ " rhs.params.tupleof[i];");
		return tmp;
	}
	
	override int opCmp(U:T)(U o) {
		auto test = this.fitness - o.fitness;
		if(test<0)
			return -1;
		else if(test>0)
			return 1;
		else
			return 0;
	}

	static auto average(T[] arr) {
		return sum(arr) /= arr.length; //not 100% sure on this
	}

	@property string csv_string() {
		auto app = appender!string();
		foreach(param; params.tupleof)
			app.put(to!string(param) ~ ",");
		return app.data[0..$-1] ~ "\n";
	}

	override string toString() {
		return this.csv_string;
	}
}

//polar method to generate normal variable, mean 0 variance 1
//ignores half the guesses, memory would make it
//thread unsafe?
double normal() {
	double u,v,s;
	do {
		u = uniform(-1f,1f);
		v = uniform(-1f,1f);
		s = u*u + v*v;
	} while(s==0 || s>1);
	return(u*sqrt(-2*log(s)/s));
}
