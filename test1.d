import ES;
import std.stdio, std.conv;
import core.stdc.math;
import std.file : readText;
import std.range : appender;
import std.string : splitLines, stripLeft, stripRight;
import std.format : formattedWrite;
import JCutils;
import std.csv;

alias Solution!Func_params Func;

void main(string[] args) {
    writeln();
    
    auto problem = new Func_toSolve(args[2],to!int(args[3]),to!double(args[4]));
    
    Init_params!Func_params init_params;
    pragma(msg, typeof((Init_params!Func_params).tupleof[0]));
    read_cfg!(double, double[2])(init_params, args[1]);
    
    auto population = new Population!Func(problem,init_params,args[5]);

    population.run();
    
    auto best = population.best();
    writeln(best[0]);
    
    problem.print_fit(best[0].params,"fit.txt");
    
    writeln();
}

//The types used for parameter values and mutabilities should implement
//their own initialisation.
//obviously no need to init explicitly for fixed arrays
alias Parameter!(double, double) d_param;

struct Func_params {
    d_param x;
    d_param y;
    
    static auto blank() {
        Func_params tmp;
        foreach(ref param; tmp.tupleof) {
            param.value = 0;
            param.mutability = 0;
        }
        return tmp;
    }
}

class Func_toSolve : Problem!Func_params {

    this (string filename, int length=1000, double noise_ampl=0) {

    }

    override double fitness_calc(Func_params fit) {
		return 0.05*(fit.x*fit.x + fit.y*fit.y) + sin(fit.x)*sin(fit.y);
    }
    
    void print_fit(Func_params fit, string filename) {
		//do nothing??
    }
}
