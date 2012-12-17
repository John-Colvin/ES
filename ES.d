import std.algorithm : partialSort, topN, sort;
import std.stdio : writeln, stdout, File, write, writefln;
import std.parallelism : taskPool;
import std.file : mkdir, minPos, FileException;
import std.datetime;
import std.conv : to;
import std.math;
import std.array;
import std.string;
import JCutils;
import yaml;
import std.exception : enforce;
public import solution;

//processing topology info? Not really sure how

//Population class, holds the core runnings of the algorithm, including 
//initialization of solutions;
class Population(T) {
    T[][] history;
    T[] history_best;
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
    bool memory = false;
    
    string style;
    string foldername;
    File fitness, means, bests;
    
    //initialises the population
    //initialise the solutions, allocate memory for parents etc...
    this(U...)(U args, string cfg_fn) {
        read_ES_config(cfg_fn);
        
        solutions = new T[pop_size];
        writefln("Initialising solutions: pop_size = %d init_num_parents = %d",
                 pop_size,num_parents);
        
        foreach(int i, ref solution; solutions) {
            solution = new T(i, args);
        }
        
        if(cmp(style,"new") == 0) {
            writeln("using new style");
            parents = new T[1];
            num_offspring = pop_size;
            memory = true;
        }
        else if(cmp(style,"old") == 0) {
            writeln("using old style");
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
        output_files_init();
        //iterate over generations.
        for(int i=1; i<=num_generations; ++i) {
            write("\rgeneration: ",i,"  ");
            stdout.flush();
            
            evaluate(); 
            _sort();
            
            if(memory) {
                history ~= class_arr_dup(solutions);    //BAD VERY SLOW!!!
                if(history_best.length == 0)
                    history_best ~= history[$-1][0..num_parents];
                else
                    topN(history_best, history[$-1]); //copies topN from right to left.
                sort(history_best); //not strictly necessary, but it hardly
                                    //takes any time for small pops.
            }
//            writeln();
//           writeln(history_best[0]);
            
            select();
            
            write_out(i);

            replace();            
        }
        //final eval and sort for results.
        evaluate();
        sort(solutions);
        writeln();
    }
    
    void output_files_init() {
        try mkdir("results");
        catch(FileException e) {}
        auto time_stamp = Clock.currTime().toISOExtString()[0..19];
        foldername = "results/output_" ~ time_stamp;
        mkdir(foldername);
        mkdir(foldername~"/gens");
        if(memory)
            mkdir(foldername~"/bests");
        fitness = File(foldername~"/fitness.txt","w");
        bests = File(foldername~"/bests.txt","w");
        if(memory)
            means = File(foldername~"/means.txt","w");
    }
    
    void write_out(int gen_num) {
//      writeln(solutions[0]);
        auto record = File(foldername~"/gens/gen"~to!string(gen_num),"w");
        record.write(csv_dump());
//      writeln("\n",solutions);
        if(memory) {
            fitness.write(history_best[0].fitness,"\n");
            means.write(parents[0].csv_string());
            bests.write(history_best[0].csv_string);
            auto best_pop = File(foldername~"/bests/best_asof_gen"~to!string(gen_num),"w");
            best_pop.write(csv_dump(history_best));
        }
        else {
            fitness.write(solutions[0].fitness,"\n");
            bests.write(solutions[0].csv_string);
        }
    }
    
    //dumps the all the solutions (paramters as csv, see 
    string csv_dump(T[] to_print) {
        auto app = appender!string();
        foreach(sol; to_print) {
            app.put(sol.csv_string());
        }
        return app.data;
    }
    
    string csv_dump() {
        return csv_dump(solutions);
    }
    
    //returns the best solutions to date
    //might have side effects......
    T[] best(int n=1) {
        enforce(n>0);
        T[] sols;
        if(memory)
            sols = history_best;
        else
            sols = solutions;

        if(n==1) {
            if(memory)
                return history_best[0..1];
            if(top_sorted)
                return sols[0..1];
            return minPos(sols)[0..1];
        }
        else {
            partialSort(sols,n);
            return(sols[0..n]);
        }
    }
    
    //evalutes the entire population in parallel.
    //need to optimise taskPool chunksize?
    void evaluate() {
        //could use taskPool.map for this?
        foreach(ref solution; taskPool.parallel(solutions)) {
//        foreach(solution; solutions) {
            solution.evaluate();
        }
    }
    
    //sorts the population by their fitness values. Smaller is better.
    void _sort() {
//      topN(solutions, num_parents); // has no sorting, only selects best
        partialSort(solutions, num_parents);
        assert(solutions[0] == minPos(solutions)[0]);
        top_sorted = true; //added with partialSort()
        partitioned = true;
    }
    
    //Selects the parents from the evaluated population
    //parents MUST be unique!!!!
    //assumes sorted
    void select() {
        if(cmp(style,"new") == 0) {
            parents[0] = child();
        }
        else
            foreach(int i, ref parent; parents)
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
        auto end_of_parents = parents.length - 1;   //not same as num_parents
                                                    //in new style unfortunately
        foreach(int i, sol; solutions) {
            //if we're on the first parent, skip it and start watching
            //for the next one.
            if(sol is to_skip) {
                if(skip < end_of_parents)
                    to_skip = parents[++skip];
                else
                    to_skip = null;
                continue;
            }
            sol.mutate(parent); //modify sol based on parent
            children_so_far++;      //add one to the child counter
            
            //check if given sol has had enough offspring
            if(children_so_far >= num_offspring) {
                if(par_ind < end_of_parents)
                    parent = parents[++par_ind];    //move to next parent
                children_so_far = 0;            //reset child counter
            }
        }
        top_sorted = false;
        full_sorted = false;
        partitioned = false;
    }
    
    T child() {
        T[] to_average;
        if(memory) {
 //           writeln(history_best);
 //           writeln("AVERAGE: ",T.average(history_best));
            return T.average(history_best);
        }
        if(!partitioned) {
            topN(solutions, num_parents);
            partitioned = true;
        }
        
        return T.average(solutions[0..num_parents]);
    }
    
    void read_ES_config(string filename) {
        Node root = Loader(filename).load();
        
        pop_size = root["pop_size"].as!int;
        num_parents = root["num_parents"].as!int;
        num_generations = root["num_generations"].as!int;
        style = root["style"].as!string;
    }
};
