import std.random : uniform;
import std.range : lockstep;
import std.traits : isArray;
import orange.util.Reflection : nameOfFieldAt;
import std.string : appender;
import std.stdio : writeln;
import JCutils;
import yaml;

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
	static if(T.tupleof.length == 0) {
		const gen_fieldsImpl = "";
	}
	else static if(T.tupleof.length -1 == i) {
		const gen_fieldsImpl = InsertFirstDimension!(typeof(T.tupleof[i].value), 2).stringof
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_range;\n" ~
						 InsertFirstDimension!(typeof(T.tupleof[i].value), 2).stringof 
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_mut_range;";
	}
	else {
		const gen_fieldsImpl = InsertFirstDimension!(typeof(T.tupleof[i].value), 2).stringof 
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_range;\n" ~ 
						 InsertFirstDimension!(typeof(T.tupleof[i].value), 2).stringof 
						 ~ " " ~ nameOfFieldAt!(T,i) ~ "_mut_range;\n" ~ 
						 gen_fieldsImpl!(T, i+1);
	}
}

//currently only works with one type at a time.
void read_cfg(Q,U,T)(ref T params, string filename) {
	Node root = Loader(filename).load();
	Node solution = root["solution"];

	auto link = AAof!(U)(params);
	
	int i=0; //has to be outside because solution is a tuple???
	foreach(Node set; solution) {
		foreach(string name, Node value; set) {
			link[name~"_range"][i][0] = value["min"].as!Q;
			link[name~"_range"][i][1] = value["max"].as!Q;
			link[name~"_mut_range"][i][0] = value["mut_min"].as!Q;
			link[name~"_mut_range"][i][1] = value["mut_max"].as!Q;
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
	Problem!T problem;

/*	this(U=bool)(T params) {
		this.params = params;
	}*/
	
	//full constructor including solution initialisation
	//has to be a template to work around a bug in D
	//mutabilities initialised to uniform. Is this right? It's gonna cause
	//problems with array parameters...
	this(U=bool)(Problem!T problem, Init_params!(T) init_params, int id) {
		this.problem = problem;
		this.id = id;
		//leave fitness as nan
		
		static if(__traits(hasMember, T, "initialise")) {
			pragma(msg,__traits(hasMember, T, "initialise"));
			params.initialise(init_params);
		}
		else {
			auto link = AAof!(double[2][1])(init_params);
			
			foreach(uint i, ref param; params.tupleof) {
				auto name = nameOfFieldAt!(T,i);
				
				static if(isArray!(typeof(param.value))) {
					double[] param_norm_vect = new double[param.value.length];
					double[] mut_norm_vect = new double[param.mutability.length];
					foreach(ref el_param_norm_vect, ref el_mut_norm_vect; lockstep(param_norm_vect, mut_norm_vect)) {
						el_param_norm_vect = uniform!"[]"(link[name~"_range"][0][0],link[name~"_range"][0][1]);
						el_mut_norm_vect = uniform!"[]"(link[name~"_mut_range"][0][0],link[name~"_mut_range"][0][1]);
					}
					param[] = param_norm_vect[];
					param.mutability[] = mut_norm_vect[];
				}
				else {
					param = uniform!"[]"(link[name~"_range"][0],link[name~"_range"][1]);
					param.mutability = uniform!"[]"(link[name~"_mut_range"][0],link[name~"_mut_range"][1]);	
				}
			}
		}
		writeln(this);
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
		problem = a.problem;
    }
	
	//reroute for constructor from Population
	//exands args to main constructor.
	this(U...)(int id, U args) {
		this(args[0], args[1], id);
	}
	
	void evaluate() {
		fitness = problem.fitness_calc(params);
	}
	
	void mutate(Solution parent) {
		id = parent.id;
		foreach(uint i, ref param; params.tupleof) {
			//should user defined types which possess the right 
			//operator primitives be allowed here?
			static assert(_is_arithmetic!(ElementTypeRecursive!(typeof(param.value))), "No default mutation 
						  implementation for non-arithmetic types");
			static if(isArray!(typeof(param.value))) {
				double[] mut_vect = new double[param.value.length];
				foreach(ref mut; mut_vect) {
					mut = normal();
				}
				param[] = parent.params.tupleof[i][] + mut_vect[]*parent.params.tupleof[i].mutability[];
			}
			else {
				param = parent.params.tupleof[i] + normal()*parent.params.tupleof[i].mutability;
			}
		}
	}
	
	auto opOpAssign(string op, U)(U rhs) {
		static if(!(op == '*' || op == '/'))
			static assert("operation: " ~op~ " not supported");
		foreach(uint i, ref param; params.tupleof) {
			static if(isArray!(typeof(param.value))) {
				static if(isArray!(U))
					mixin("param[] " ~ op ~"= rhs[];");
				else
					mixin("param[] " ~ op ~"= rhs;");
			}
			else
				mixin("param " ~ op ~ "= rhs;");
		}
		return this;
	}

	auto opOpAssign(string op, U:Solution!T)(U rhs) {
		foreach(uint i, ref param; params.tupleof) {
			static if(isArray!(typeof(param.value)))
				mixin("param[] " ~ op ~"= rhs.params.tupleof[i][];");
			else
				mixin("param " ~ op ~ "= rhs.params.tupleof[i];");
		}
		return this;
	}

	auto opBinary(string op, U:Solution!T)(U rhs) {
		U tmp = new U;
		foreach(uint i, ref param; tmp.params.tupleof) {
			static if(isArray!(typeof(param.value)))
				mixin("param[] = this.params.tupleof[i][] " ~ op ~ " rhs.params.tupleof[i][];");
			else
				mixin("param = this.params.tupleof[i] " ~ op ~ " rhs.params.tupleof[i];");
		}
		return tmp;
	}
	
	auto opBinary(string op, U)(U rhs) {
		Solution!T tmp = new Solution!T;
		foreach(uint i, ref param; tmp.params.tupleof) {
			static if(isArray!(typeof(param.value))) {
				static if(isArray!(U))
					mixin("param[] = this.params.tupleof[i][] " ~ op ~ " rhs[];");
				else
					mixin("param[] = this.params.tupleof[i][] " ~ op ~ " rhs;");
			}	
			else
				mixin("param = this.params.tupleof[i] " ~ op ~ " rhs;");
		}
		return tmp;
	}
	
	override int opCmp(Object o) {
		auto test = this.fitness - (cast(Solution!T)o).fitness;
		if(test<0)
			return -1;
		else if(test>0)
			return 1;
		else
			return 0;
	}

	static auto average(Solution[] arr) {
		return mean(arr);   //I guess this could be overidden to something interesting??
	}

	@property string csv_string() {
		auto app = appender!string();
		app.put(to!string(id) ~ "," ~ to!string(fitness) ~ ",");
		foreach(param; params.tupleof)
			app.put(to!string(param) ~ ",");
		return app.data[0..$-1] ~ "\n";
	}

	override string toString() {
		return this.csv_string;
	}
}

//really need some unittests. No idea how considering how heavily templated and interdependant
//everything is...

class Problem(T) {
	abstract double fitness_calc(T fit);
}
