public import ES;

//no support for anything with higher dimension than 1;
class A (T){
	T params;

	this(T params) {
		this.params = params;
	}

	auto opOpAssign(string op, T)(T rhs) {
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

	auto opOpAssign(string op, T:A)(T rhs) {
		foreach(uint i, ref param; params.tupleof)
			static if(_is_arr!param)
				mixin("param[] " ~ op ~"= rhs.params.tupleof[i][];");
			else
				mixin("param " ~ op ~ "= rhs.params.tupleof[i];");
		return this;
	}

	auto opBinary(string op)(A rhs) {
		A tmp = new A;
		foreach(uint i, ref param; tmp.params.tupleof)
			static if(_is_arr!param)
				mixin("param[] = this.params.tupleof[i][] " ~ op ~ " rhs.params.tupleof[i][];");
			else
				mixin("param = this.params.tupleof[i] " ~ op ~ " rhs.params.tupleof[i];");
		return tmp;
	}

	static auto average(A[] arr) {
		A tmp = new A;
		foreach(el; arr) {
			tmp += el;
		}
		return tmp /= arr.length;
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
