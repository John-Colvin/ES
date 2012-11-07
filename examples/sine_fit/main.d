import std.stdio, std.conv;
import sine_fit;

void main(string[] args) {
//	FloatingPointControl fpctrl;
//	fpctrl.enableExceptions(FloatingPointControl.severeExceptions);     //for debugging
	if(args.length != 6) {
//		throw new Exception("Incorrect number of arguments. Should be 5");
		writeln("using defaults");
		args = new string[6];
		args[1] = "/home/john/Git/John-Colvin/ES/examples/sine_fit/test_cfg.yaml";
		args[2] = "generate";//"/home/john/Documents/Data_from_boris/nice/prep/_r_1.dat";
		args[3] = "1000";
		args[4] = "0.2";
		args[5] = "/home/john/Git/John-Colvin/ES/examples/sine_fit/ES_cfg.yaml";
	}
	
	auto problem = new Data_fit(args[2],to!int(args[3]),to!double(args[4]));
	
	Init_params init_params;
	read_cfg(init_params, args[1]);
	
	auto population = new Population!(Sine_fit)(problem,init_params,args[5]);

	population.run();
	
	auto best = population.best();
	writeln(best);
	
	problem.print_fit(best[0],"fit.txt");
}
