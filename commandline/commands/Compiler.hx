package commands;

class Compiler {

	static function __runLime(args:Array<String>, command:Array<String>) {
		var finalArgs = command.concat(args);
		Sys.println("Running: lime " + finalArgs.join(" "));
		Sys.command("lime", finalArgs);
	}

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

		return switch(Sys.systemName()) {
			case "Windows": "windows";
			case "Mac": "macos";
			case "Linux": "linux";
			default: "windows";
		}
	}
}
