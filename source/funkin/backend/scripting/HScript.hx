package funkin.backend.scripting;

using StringTools;

import hscript.*;
import hscript.Parser;
import openfl.Assets;

class HScript extends Script {
    public var interp:Interp;
    public var parser:Parser;
    public var expr:Expr;
    public var code:String = null;
    var __importedPaths:Array<String>;

    public static function initParser() {
        var parser = new Parser();
        parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
        parser.preprocessorValues = Script.getDefaultPreprocessors();
        return parser;
    }

    public override function onCreate(path:String) {
        super.onCreate(path);

        interp = new Interp();

        try {
            if(Assets.exists(rawPath)) code = Assets.getText(rawPath);
        } catch(e:Dynamic) {
            Logs.error('Error while reading $path: ${Std.string(e)}');
        }

        parser = initParser();
        __importedPaths = [path];

        interp.errorHandler = _errorHandler;
        interp.warnHandler = _warnHandler;
        interp.importFailedCallback = importFailedCallback;
        interp.staticVariables = Script.staticVariables;
        interp.allowStaticVariables = interp.allowPublicVariables = true;

        interp.variables.set("trace", Reflect.makeVarArgs((args) -> {
            var v:String = Std.string(args.shift());
            for(a in args) v += ", " + Std.string(a);
            this.trace(v);
        }));

        #if GLOBAL_SCRIPT
        funkin.backend.scripting.GlobalScript.call("onScriptCreated", [this, "hscript"]);
        #end

        loadFromString(code);
    }

    public override function loadFromString(code:String) {
        try {
            if(code != null && code.trim() != "")
                expr = parser.parseString(code, fileName);
        } catch(e:Dynamic) {
            _errorHandler(e);
        }

        return this;
    }

    private function importFailedCallback(cl:Array<String>, ?asName:String):Bool {
        if(_importFailedCallback(cl, "source/") || _importFailedCallback(cl, "")) {
            return true;
        }
        return false;
    }

    private function _importFailedCallback(cl:Array<String>, prefix:String):Bool {
        var assetsPath = 'assets/$prefix${cl.join("/")}';
        for(hxExt in ["hx", "hscript", "hsc", "hxs"]) {
            var p = '$assetsPath.$hxExt';
            if(__importedPaths.contains(p))
                return true;
            if(Assets.exists(p)) {
                var code = Assets.getText(p);
                var expr:Expr = null;
                try {
                    if(code != null && code.trim() != "") {
                        parser.line = 1;
                        expr = parser.parseString(code, cl.join("/") + "." + hxExt);
                    }
                } catch(e:Dynamic) {
                    _errorHandler(e);
                }
                if(expr != null) {
                    @:privateAccess
                    interp.exprReturn(expr);
                    __importedPaths.push(p);
                }
                return true;
            }
        }
        return false;
    }

    private function _errorHandler(error:Dynamic) {
        var err = Std.string(error);
        Logs.traceColored([
            Logs.logText(fileName + ": ", GREEN),
            Logs.logText(err, RED)
        ], ERROR);
    }

    private function _warnHandler(error:Dynamic) {
        var err = Std.string(error);
        Logs.traceColored([
            Logs.logText(fileName + ": ", GREEN),
            Logs.logText(err, YELLOW)
        ], WARNING);
    }

    public override function setParent(parent:Dynamic) {
        interp.scriptObject = parent;
    }

    public override function onLoad() {
        @:privateAccess
        interp.execute(parser.mk(EBlock([]), 0, 0));
        if(expr != null) {
            interp.execute(expr);
            call("new", []);
        }

        #if GLOBAL_SCRIPT
        funkin.backend.scripting.GlobalScript.call("onScriptSetup", [this, "hscript"]);
        #end
    }

    public override function reload() {
        interp.allowStaticVariables = interp.allowPublicVariables = false;
        var savedVariables:Map<String, Dynamic> = [];
        for(k=>e in interp.variables) {
            if(!Reflect.isFunction(e)) savedVariables[k] = e;
        }
        var oldParent = interp.scriptObject;
        onCreate(path);

        for(k=>e in Script.getDefaultVariables(this))
            set(k, e);

        load();
        setParent(oldParent);

        for(k=>e in savedVariables)
            interp.variables.set(k, e);

        interp.allowStaticVariables = interp.allowPublicVariables = true;
    }

    private override function onCall(funcName:String, parameters:Array<Dynamic>):Dynamic {
        if(interp == null) return null;
        if(!interp.variables.exists(funcName)) return null;

        var func = interp.variables.get(funcName);
        if(func != null && Reflect.isFunction(func))
            return Reflect.callMethod(null, func, parameters);

        return null;
    }

    public override function get(val:String):Dynamic {
        return interp.variables.get(val);
    }

    public override function set(val:String, value:Dynamic) {
        interp.variables.set(val, value);
    }

    public override function trace(v:Dynamic) {
        var posInfo = interp.posInfos();
        Logs.traceColored([
            Logs.logText('${fileName}:${posInfo.lineNumber}: ', GREEN),
            Logs.logText(Std.isOfType(v, String) ? v : Std.string(v))
        ], TRACE);
    }

    public override function setPublicMap(map:Map<String, Dynamic>) {
        this.interp.publicVariables = map;
    }
}
