package commands;

class Compiler {
	public static function test(args:Array<String>) {
		__runLime(args, ["test", getBuildTarget(), "-DTEST_BUILD"]);
	}
	public static function build(args:Array<String>) {
		__runLime(args, ["build", getBuildTarget(), "-DTEST_BUILD"]);
	}
	public static function release(args:Array<String>) {
		__runLime(args, ["build", getBuildTarget()]);
	}
	public static function testRelease(args:Array<String>) {
		__runLime(args, ["test", getBuildTarget()]);
	}
	public static function run(args:Array<String>) {
		__runLime(args, ["run", getBuildTarget()]);
	}

	public static function getBuildTarget():String {
	var args = Sys.args();

	for (a in args) {
		switch (a.toLowerCase()) {
			case "android", "windows", "linux", "mac", "macos", "ios", "html5":
				return a.toLowerCase();
		}
	}

	// fallback to system
	return switch(Sys.systemName()) {
		case "Windows": "windows";
		case "Mac": "macos";
		case "Linux": "linux";
		default: "windows";
	}
	}
