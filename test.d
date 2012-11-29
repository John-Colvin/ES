import ES_interface;
import std.stdio, std.conv;

alias Solution!Sine_fit_params Sine_fit;

void main(string[] args) {
	auto problem = new Data_fit(args[2],to!int(args[3]),to!double(args[4]));
	
	Init_params!Sine_fit_params init_params;
	read_cfg!(double[2][])(init_params, args[1]);
	
	auto population = new Population!Sine_fit(problem,init_params,args[5]);

	population.run();
	
	auto best = population.best();
	writeln(best);
	
	problem.print_fit(best[0],"fit.txt");
}

//The types used for parameter values and mutabilities should implement
//their own initialisation.
//obviously no need to init explicitly for fixed arrays
alias Parameter!(double[1], double[1]) d_param;

struct Sine_fit_params {
	d_param amplitude;
	d_param frequency;
	d_param phase;
	d_param offset;
	
	static auto blank() {
		Sine_fit_params tmp;
		foreach(ref param; tmp.tupleof) {
			param[] = 0;
			param.mutability[] = 0;
		}
		return tmp;
	}
}

class Data_fit : Problem!Sine_fit_params {
	double[] dataX;
	double[] dataY;
	double[] dataY_err;

	this (string filename, int length=1000, double noise_ampl=0) {
		if(filename == "generate") {
			dataX = new double[length];
			dataY = new double[length];
//			auto divisor = to!double(length) / 10;
			auto divisor = 1.5;
			foreach(int i, ref datax; dataX) {
				datax = to!double(i)/divisor;
				dataY[i] = sin(datax) + noise_ampl*normal();
			}
		}
		else {
			auto f = readText(filename);
			
            //this is specific to a certain file format. Need a general approach
			auto cleaned_app = appender!(char[])();
			cleaned_app.reserve(f.length);
			foreach(line; f.splitLines()){
				if(line[0] == '#')
					continue;
				line = stripLeft(line);
				char[] temp;
				bool lock=false;
				foreach(c;line) {
					if(!lock) {
						temp ~= c;
						if(c==' ')
							lock = true;
					}
					else if(c != ' ') {
						temp ~= c;
						lock = false;
					}
				}
				cleaned_app.put(temp ~ '\n');
			}
			auto cleaned = stripRight(cleaned_app.data);
			
			struct Layout { 
				double time;
				double time_corr; 
				double dm; 
				double de; 
			}
			auto records = csvReader!Layout(cleaned,' ');
			foreach(record; records) {
				dataX ~= record.time + record.time_corr - 2440000.5;
				dataY ~= record.dm;
				dataY_err ~= record.de;
			}
		}
	}

	override double fitness_calc(Sine_fit_params fit) {
		double fitness = 0;
		//could all definitely be much faster. Array ops?
		for(int i = 0; i < dataX.length; ++i) {
			double result = 0;

			for(int j = 0; j < fit.amplitude.length; ++j) {
				result += fit.offset[j] + fit.amplitude[j] * sin(dataX[i] * fit.frequency[j] + fit.phase[j]);
			}

			fitness += (result - dataY[i]) * (result - dataY[i]);
		}
		fitness /= dataX.length;
		return fitness;
	}
	
	void print_fit(Sine_fit_params fit, string filename) {
		auto app = appender!string();
		formattedWrite(app,"#Data,Fit\n");
		for(int i = 0; i < dataX.length; ++i) {
			double result = 0;
			for(int j = 0; j < fit.amplitude.length; ++j) {
				result += fit.offset[j] + fit.amplitude[j] * sin(dataX[i] * fit.frequency[j] + fit.phase[j]);
			}
			formattedWrite(app, "%.4f,%.6f,%.6f\n", dataX[i], dataY[i], result);
		}
		std.file.write(filename,app.data);
	}
}
