public import ES;
import std.math, std.random, std.stdio, std.file, std.string;
import std.array, std.conv, std.csv, std.format;

@safe
class Init_params {
	double[2][] amplitude_range;
	double[2][] amplitude_mut_range;
	double[2][] frequency_range;
	double[2][] frequency_mut_range;
	double[2][] phase_range;
	double[2][] phase_mut_range;
	double[2][] offset_range;
	double[2][] offset_mut_range;
	int num_waves;
	
	this (int num_waves) {
		this.num_waves = num_waves;
		amplitude_range = new double[2][num_waves];
		amplitude_mut_range = new double[2][num_waves];
		frequency_range = new double[2][num_waves];
		frequency_mut_range = new double[2][num_waves];
		phase_range = new double[2][num_waves];
		phase_mut_range = new double[2][num_waves];
		offset_range = new double[2][num_waves];
		offset_mut_range = new double[2][num_waves];
	}
}

/*
//need to consider general case of covariance. Could be hard.
class Parameter {
	abstract void mutate();
	
}
*/
//parameters must support some sort of averaging operation
class Sine_fit : Solution!(Sine_fit) {
	double[] amplitude;
	double[] frequency;
	double[] phase;
	double[] offset;
	int num_waves;
	Init_params init_params;
	
	//basic constructor for a blank sine_fit
	//has to be template to overcome bug in d
	this(T=bool)(int num_waves_in) {
		this.num_waves = num_waves_in;
		amplitude = new double[num_waves];
		frequency = new double[num_waves];
		phase = new double[num_waves];
		offset = new double[num_waves];
		
		foreach(int i, dummy; amplitude) {
			amplitude[i] = 0;
			frequency[i] = 0;
			phase[i] = 0;
			offset[i] = 0;
		}
        
        fitness = double.infinity;
	}

	//full constructor including solution initialisation
	//has to be a template to work around a bug in D
	this(T=bool)(Problem!Sine_fit problem, Init_params params, int id) {
/*		if(id == -1)
			this(params.num_waves);
		else*/ {	
			super(problem, this);
			this.id = id;
			init_params = params;
		
			num_waves = init_params.num_waves;
		
			amplitude = new double[num_waves];
			frequency = new double[num_waves];
			phase = new double[num_waves];
			offset = new double[num_waves];
			
			foreach(int i, dummy; amplitude) {
				amplitude[i] = uniform_local(init_params.amplitude_range[i][0], init_params.amplitude_range[i][1]);
				frequency[i] = uniform_local(init_params.frequency_range[i][0], init_params.frequency_range[i][1]);
				phase[i] = uniform_local(init_params.phase_range[i][0], init_params.phase_range[i][1]);
				offset[i] = uniform_local(init_params.offset_range[i][0], init_params.offset_range[i][1]);
			}
//			writefln("%10s %10s %10s %10s",this.amplitude,this.frequency,this.phase,this.offset);
		}
	}
	
	//reroute for constructor from Population
	//exands args to main constructor.
	this(U...)(int id, U args) {
		this(args[0], args[1], id);
	}
    
    //copy constructor. Again, has to be a bloody template.....
    this(T = bool)(Sine_fit a) {
		super(a);
        num_waves = a.num_waves;
        init_params = a.init_params;
        
        amplitude = a.amplitude.dup;
		frequency = a.frequency.dup;
		phase = a.phase.dup;
		offset = a.offset.dup;
    }
	
	override void mutate(Sine_fit parent) {
		foreach(int i, dummy; amplitude) {
			amplitude[i] = parent.amplitude[i] + normal()*init_params.amplitude_mut_range[i][1];
			frequency[i] = parent.frequency[i] + normal()*init_params.frequency_mut_range[i][1];
			phase[i] = parent.phase[i] + normal()*init_params.phase_mut_range[i][1];
			offset[i] = parent.offset[i] + normal()*init_params.offset_mut_range[i][1];
		}
	}
	
	override string toString() {
		auto app = appender!string();
		formattedWrite(app, "Fitness = %10g   id = %d\n", fitness, id);
		formattedWrite(app, " Amplitude  Frequency      Phase     Offset\n"); 
		foreach(int i, dummy; amplitude) {
			formattedWrite(app, "%10g %10g %10g %10g\n", amplitude[i], frequency[i], phase[i], offset[i]);
		}
		return app.data;
	}
	
	string csv_string() {
		auto app = appender!string();
		formattedWrite(app, "%d,%g", id, fitness);
		foreach(int i, dummy; amplitude) {
			formattedWrite(app, ",%g,%g,%g,%g\n", amplitude[i], frequency[i], phase[i], offset[i]);
		}
		return app.data;
	}
	
	static Sine_fit average(Sine_fit[] sols) {
		Sine_fit av = new Sine_fit(sols[0].num_waves);
		foreach(sol; sols)
			for(int i=0; i<sols[0].num_waves; ++i) {
				av.amplitude[i] += sol.amplitude[i];
				av.frequency[i] += sol.frequency[i];
				av.phase[i] += sol.phase[i];
				av.offset[i] += sol.offset[i];
			}
		av /= sols.length;
		return av;
	}
	
/*	void opAssign(string op)(Sine_fit rhs) {
		static if(op == "+=") {
			foreach(int i, dummy; amplitude) {
				amplitude[i] += rhs.amplitude[i];
				frequency[i] += rhs.frequency[i];
				phase[i] += rhs.phase[i];
				offset[i] += rhs.offset[i];
			}
		}
		else
			static assert(0, "Operator "~op~" not implemented for type Sine_fit");
	}*/
	auto opOpAssign(string op, T)(T rhs) {
		static if(op == "/") {
			foreach(int i, dummy; amplitude) {
				amplitude[i] /= rhs;
				frequency[i] /= rhs;
				phase[i] /= rhs;
				offset[i] /= rhs;
			}
			return this;
		}
		else
			static assert(0, "Operator "~op~"= not implemented");
	}
    
    Sine_fit opBinary(string op)(Sine_fit rhs) {
        static if(op == "-") {
            enforce(this.num_waves == rhs.num_waves);
            Sine_fit res = new Sine_fit(this.num_waves);
            
            for(int i=0; i<sols[0].num_waves; ++i) {
				res.amplitude[i] = amplitude[i] - sol.amplitude[i];
				res.frequency[i] = frequency[i] - sol.frequency[i];
				res.phase[i] = phase[i] - sol.phase[i];
				res.offset[i] = offset[i] -  sol.offset[i];
            }
        }
        else
            static assert(0, "Operator "~op~" not implemented");
    }
}

double uniform_local(double min, double max) {
	if(min == max)
		return min;
	return uniform(min, max);
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

class Data_fit : Problem!(Sine_fit) {
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

	override double fitness_calc(Sine_fit fit) {
		double fitness = 0;

		foreach(int i, x; dataX) {
			double result = 0;
			foreach(o,a,w,p; lockstep(fit.offset,fit.amplitude,fit.frequency,fit.phase)) {
				result += o + a*sin(w*x + p);
			}
			fitness += (result - dataY[i]) * (result - dataY[i]);
		}
		fitness /= dataX.length;
		return fitness;
	}
	
	void print_fit(Sine_fit fit, string filename) {
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
