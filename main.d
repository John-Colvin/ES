import std.stdio, std.conv;
import sine_fit;

void main(string[] args) {
//	FloatingPointControl fpctrl;
//	fpctrl.enableExceptions(FloatingPointControl.severeExceptions);     //for debugging
	if(args.length != 8) {
		throw new Exception("Incorrect number of arguments. Should be 7");
/*		writeln("using defaults");
		args = new string[6];
		args[1] = "/home/john/Documents/Data from boris/nice/prep/_r_1.dat";
		args[2] = " /home/john/workspace/Evol_Strat/src/evol_cfg.xml";
		args[3] = "12";
		args[4] = "4";
		args[5] = "4";
		args[6] = "1000";
		args[7] = "0.2";*/
	}
	
	auto problem = new Data_fit(args[1],to!int(args[6]),to!double(args[7]));
	
	Init_params init_params;
	read_cfg(init_params, args[2]);
	
	auto pop_size = to!int(args[3]);
	auto num_parents = to!int(args[4]);
	auto num_generations = to!int(args[5]);
	
	auto population = new Population!(Sine_fit)(pop_size,num_parents,problem,init_params);

	population.run(num_generations);
	
	auto best = population.best();
	writeln(best);
	
	problem.print_fit(best[0],"fit.txt");
}