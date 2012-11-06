import std.algorithm, std.stdio, std.parallelism, std.file;
import std.datetime, std.conv, std.math, std.array;
import yaml, orange.util.Reflection, JCutils;
import std.exception;

// need to add support for memory. Maybe need population to be list of lists?
// keep track of best so far. Need some more general way of processing the
// info. Not really sure how

//Population class, holds the core runnings of the algorithm, including 
//initialization of solutions;
class Population (T) {
    T[] history;
	T[] solutions;
	T[] parents;
	int num_parents;
	int num_offspring;
	int pop_size;
    int num_generations;
	bool top_sorted = false;
	bool full_sorted = false;
	bool partitioned = false;
	bool parent_list_up_to_date = false;
	string style;
	
	//initialises the population
	//initialise the solutions, allocate memory for parents etc...
	this(U...)(U args, string cfg_fn) {
        read_ES_config(cfg_fn);
        
		solutions = new T[pop_size];
		writefln("Initialising solutions: pop_size = %d	init_num_parents = %d",
				 pop_size,num_parents);
		
		foreach(int i, ref solution; solutions) {
			solution = new T(true, i, args);
		}
		
		this.style = style;
		if(cmp(style,"new") != 0) {
			parents = new T[1];
			num_parents = 1;
			num_offspring = pop_size;
		}
		else if(cmp(style,"old") != 0) {
			parents = new T[num_parents];
			if(fmod(pop_size - num_parents,num_parents))
				throw new Exception("pop_size - num_parents must be divisible by num_parents");
			num_offspring = (pop_size - num_parents) / num_parents;
		}
		else
			throw new Exception("style \""~style~"\" not supported");
		
		writeln("num_offspring = ",num_offspring);
	}
	
	//runs the algorithm
	void run() {
		//create output files. This should be dealt with elsewhere.
		try	mkdir("results");
		catch(FileException e) {}
		auto time_stamp = Clock.currTime().toISOExtString()[0..19];
		auto foldername = "results/output_" ~ time_stamp;
		mkdir(foldername);
		auto fitness = File("fitness.txt","w");
		
		//iterate over generations.
		for(int i=1; i<=num_generations; ++i) {
			write("\rgeneration: ",i,"  ");
			stdout.flush();
			
			evaluate();	
			_sort();
			
//			writeln(solutions[0]);
			auto record = File(foldername~"/gen"~to!string(i),"w");
			record.write(csv_dump());
//			writeln("\n",solutions);
			fitness.write(solutions[0].fitness,"\n");
			
			select();
			replace();
		}
		//final eval and sort for results.
		evaluate();
		sort(solutions);
		writeln();
	}
	
	//dumps the all the solutions (paramters as csv, see 
	string csv_dump() {
		auto app = appender!string();
		foreach(sol; solutions) {
			app.put(sol.csv_string());
		}
		return app.data;
	}
	
	//returns the best solution to date
	T[] best(int n=1) {
		enforce(n>0);
		if(n==1) {
			if(top_sorted)
				return solutions[0..1];
			else {
				return minPos(solutions)[0..1];
			}
		}
		else {
			partialSort(solutions,n);
			return(solutions[0..n]);
		}
	}
	
	//evalutes the entire population in parallel.
	//need to optimise taskPool chunksize?
	void evaluate() {
		foreach(ref solution; taskPool.parallel(solutions)) {
//		foreach(solution; solutions) {
			solution.evaluate();
		}
	}
	
	//sorts the population by their fitness values. Smaller is better.
	void _sort() {
//		topN(solutions, num_parents); // has no sorting, only selects best
		partialSort(solutions, num_parents);
		assert(solutions[0] == minPos(solutions)[0]);
		top_sorted = true; //added with partialSort()
		partitioned = true;
	}
	
	//Selects the parents from the evaluated population
	//parents MUST be unique!!!!
	//assumes sorted
	void select() {
		if(cmp(style,"new") != 0) {
			parents[0] = child();
		}
		else
			foreach(int i, parent; parents)
				parent = solutions[i];
		//sort(parents);    //this will need changing, ok for now as parents are
							//already in order
		parent_list_up_to_date = true;
	}
	
    //new simpler version of replace()
	void replace() {
		int skip = 0, par_ind = 0;
		T to_skip = parents[skip];
		T parent = parents[par_ind];
		int children_so_far = 0;
		
		foreach(sol; solutions) {
			//if we're on the first parent, skip it and start watching
			//for the next one.
			if(sol is to_skip) {   //will this work??  should do
				to_skip = parents[++skip];
				continue;
			}
			sol._mutate(parent);	//modify sol based on parent
			children_so_far++;		//add one to the child counter
			//check if given sol has had enough offspring
			if(children_so_far >= num_offspring) {	
				parent = parents[++par_ind];	//move to next parent
				children_so_far = 0;			//reset child counter
			}
		}
		top_sorted = false;
		full_sorted = false;
		partitioned = false;
	}
	
	T child() {
		if(!partitioned) {
			topN(solutions, num_parents);
			partitioned = true;
		}
		return T.average(solutions);	
	}
    
    void read_ES_config(string filename) {
        Node root = Loader(filename).load();
        
        pop_size = root["pop_size"].as!int;
        num_parents = root["num_parents"].as!int;
        num_generations = root["num_generations"].as!int;
        style = root["style"].as!string;        
    }
    
	//this doesn't work with the new parents
	/+
	//Replaces solutions not selected as parents with mutations from parents.
	//assumes parents is in same order as sols and parents only contains 
	//unique values.
	//Still not 100% about this, but it seems to work. I doubt this a slow bit
	//but could easily resort to pointers here if necessary.
	void _replace() {
		parent_list_up_to_date = false;		//in the case of a , strat, not in +
		int pos = 0, next_skip = 0;
		foreach(parent; parents) {
			int j;
			j=0;
			//scan over population from position of last mutation, skipping
			//any parents.
			while (j<num_offspring) {
				if(is(solutions[pos] == parents[next_skip])) {
					if(next_skip < num_parents - 1)
						++next_skip;
				}
				else {
					solutions[pos]._mutate(solutions[parent]);
					++j;
				}
				++pos;
			}
		}
		top_sorted = false;
		full_sorted = false;
		partitioned = false;
	}
	+/
};

//Base class for solutions. It is aware of both it's immediately derived 
//object and the problem that is to be solved.
class Solution (T){
	double fitness;
	Problem!(T) problem;
	T derived_object;
	int id;
	
	this(Problem!(T) problem, T derived_object) {
		this.problem = problem;
		this.derived_object = derived_object;
	}
	
	void evaluate() {
		fitness = problem.fitness_calc(derived_object);
//		writeln(fitness);
	}
	
	void _mutate(T parent) {
		id = parent.id;
		mutate(parent);
	}
	
	abstract void mutate(T parent);
	
	override int opCmp(Object o) {
		auto test = this.fitness - (cast(T) o).fitness;
		if(test<0)
			return -1;
		else if(test>0)
			return 1;
		else
			return 0;
	}
	
	//should i force toString and csv_string to be implemented
	//by using abstract?
}

//Base class for the problem
class Problem (T){
	abstract double fitness_calc(T solution);
}

void read_cfg(T)(ref T params, string filename) {
	Node root = Loader(filename).load();
	Node solution = root["solution"];

	params = new T(to!int(solution.length));

	auto link = string_access!(double[2][])(params);
	
	int i=0;
	foreach(Node set; solution) {
		foreach(string name, Node value; set) {
			link[name~"_range"][i][0] = value["min"].as!double;
			link[name~"_range"][i][1] = value["max"].as!double;
			link[name~"_mut_range"][i][0] = value["mut_min"].as!double;
			link[name~"_mut_range"][i][1] = value["mut_max"].as!double;
		}
		++i;
	}
}
