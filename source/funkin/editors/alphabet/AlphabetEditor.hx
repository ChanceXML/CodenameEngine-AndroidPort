package funkin.editors.alphabet;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.camera.FlxCamera;
import flixel.group.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import funkin.backend.system.framerate.Framerate;
import funkin.backend.utils.XMLUtil.AnimData;
import funkin.editors.ui.UIContextMenu.UIContextMenuOption;
import funkin.editors.ui.UIButtonList;
import funkin.editors.ui.UIText;
import funkin.editors.ui.UITextBox;
import funkin.editors.ui.UISliceSprite;
import funkin.editors.ui.UIButton;
import funkin.game.Character;
import haxe.xml.Printer;

@:access(funkin.menus.ui.Alphabet)
class AlphabetEditor extends UIState {
    static var __typeface:String;

    public static var instance(get, null):AlphabetEditor;
    private static inline function get_instance() return FlxG.state is AlphabetEditor ? cast FlxG.state : null;

    public var topMenu:Array<UIContextMenuOption>;
    public var topMenuSpr:UITopMenu;
    public var uiGroup:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

    var editorCamera:FlxCamera;
    var uiCamera:FlxCamera;

    public function new(typeface:String) {
        super();
        if (typeface != null) __typeface = typeface;
    }

    inline function translate(id:String, ?args:Array<Dynamic>) return TU.translate("editor.alphabet." + id, args);

    public var brokenWarning:UIText;
    public var tape:Alphabet;
    public var bigLetter:Alphabet;
    public var curLetter:Int = 0;
    public var targetX:Float = 0;

    public var queueReorder:Bool = false;
    public var componentList:UIButtonList<ComponentButton>;

    public var glyphCreateWindow:UISliceSprite;
    public var glyphChar:UITextBox;
    public var confirmGlyph:UIButton;
    public var deleteGlyph:UIButton;

    public var infoWindow:GlyphInfoWindow;
    public var curSelectedComponent:AlphabetComponent = null;
    public var curSelectedData:AlphabetLetterData = null;
    public var outlineIdx:Int = -1;

    public var defaultTmr:Float = 0.0;
    public var charsForDefault:Array<Array<String>> = [];

    var lastChar:String = "";

    public override function create() {
        super.create();

        WindowUtils.suffix = " (" + translate("name") + ")";
        SaveWarning.selectionClass = AlphabetSelection;
        SaveWarning.saveFunc = () -> { _file_save(null); };

        // --- Top menu ---
        topMenu = [
            {
                label: translate("topBar.file"),
                childs: [
                    { label: translate("file.save"), keybind: [CONTROL, S], onSelect: _file_save },
                    { label: translate("file.saveAs"), keybind: [CONTROL, SHIFT, S], onSelect: _file_saveas },
                    null,
                    { label: translate("file.exit"), onSelect: _file_exit }
                ]
            },
            {
                label: translate("topBar.edit"),
                childs: [
                    { label: translate("glyph.deleteCurGlyph"), onSelect: function(_) {} }, // empty but valid
                    { label: "Edit Main Data", onSelect: _edit_main }
                ]
            },
            {
                label: translate("topBar.view"),
                childs: [
                    { label: translate("view.zoomIn"), keybind: [CONTROL, NUMPADPLUS], onSelect: function(_) {} },
                    { label: translate("view.zoomOut"), keybind: [CONTROL, NUMPADMINUS], onSelect: function(_) {} },
                    { label: translate("view.resetZoom"), keybind: [CONTROL, NUMPADZERO], onSelect: function(_) {} }
                ]
            },
            {
                label: "Tape",
                childs: [
                    { label: "Move Tape Left", keybind: [LEFT], onSelect: _tape_left },
                    { label: "Move Tape Right", keybind: [RIGHT], onSelect: _tape_right }
                ]
            }
        ];

        editorCamera = FlxG.camera;

        uiCamera = new FlxCamera();
        uiCamera.bgColor = 0;
        FlxG.cameras.add(uiCamera, false);

        var bg = new FlxSprite(0, 0).makeSolid(Std.int(FlxG.width + 100), Std.int(FlxG.height + 100), 0xFF7f7f7f);
        bg.cameras = [editorCamera];
        bg.scrollFactor.set();
        bg.screenCenter();
        add(bg);

        topMenuSpr = new UITopMenu(topMenu);
        topMenuSpr.cameras = uiGroup.cameras = [uiCamera];

        tape = new Alphabet(0, 70, "", __typeface);
        tape.alignment = CENTER;
        tape.renderMode = MONOSPACE;
        add(tape);

        bigLetter = new Alphabet(0, 0, "", "<SKIP>");
        bigLetter.copyData(tape);
        bigLetter.alignment = CENTER;
        bigLetter.scale.set(4, 4);
        bigLetter.updateHitbox();
        bigLetter.screenCenter();
        add(bigLetter);

        tape.x = targetX;

        brokenWarning = new UIText(0, 550, FlxG.width, "", 32);
        brokenWarning.alignment = CENTER;
        brokenWarning.color = 0xFFFF6969;
        add(brokenWarning);

        // --- Glyph UI ---
        glyphCreateWindow = new UISliceSprite(FlxG.width - 15, topMenuSpr.bHeight + 15, 200, 150, "editors/ui/context-bg");
        glyphCreateWindow.x -= glyphCreateWindow.bWidth;
        uiGroup.add(glyphCreateWindow);

        glyphChar = new UITextBox(glyphCreateWindow.x + 15, glyphCreateWindow.y + 15, "", glyphCreateWindow.bWidth - 30);
        glyphCreateWindow.members.push(glyphChar);

        confirmGlyph = new UIButton(glyphChar.x, glyphChar.y + glyphChar.bHeight + 15, translate("glyph.newGlyph"), function() {
            if (deleteGlyph.selectable) {
                curLetter = tape.manualLetters.indexOf(lastChar) + charsForDefault.length;
                changeLetter(0);
            } else {
                tape.manualLetters.push(lastChar);
                tape.text = "";
                for (def in charsForDefault) tape.text += def[Std.int(Math.floor(defaultTmr) % def.length)] + " ";
                tape.text += tape.manualLetters.join(" ");

                for (i in 0...tape.fastGetData(lastChar).components.length) {
                    var anim = bigLetter.text + i;
                    bigLetter.animation.remove(anim);
                    tape.animation.remove(anim);
                }

                tape.letterData.set(lastChar, {
                    isDefault: false,
                    advance: Math.NaN,
                    advanceEmpty: true,
                    components: [],
                    startIndex: 0
                });

                curLetter = tape.manualLetters.length - 1 + charsForDefault.length;
                changeLetter(0);
            }
        }, glyphChar.bWidth);
        confirmGlyph.selectable = false;
        glyphCreateWindow.members.push(confirmGlyph);

        deleteGlyph = new UIButton(glyphChar.x, confirmGlyph.y + confirmGlyph.bHeight + 5, translate("glyph.deleteGlyph"), function() {
            final charIdx = tape.manualLetters.indexOf(lastChar);
            tape.manualLetters.splice(charIdx, 1);
            tape.text = "";
            for (def in charsForDefault) tape.text += def[Std.int(Math.floor(defaultTmr) % def.length)] + " ";
            tape.text += tape.manualLetters.join(" ");

            for (i in 0...tape.fastGetData(lastChar).components.length) {
                var anim = bigLetter.text + i;
                bigLetter.animation.remove(anim);
                tape.animation.remove(anim);
            }
            tape.letterData.remove(lastChar);

            changeLetter((curLetter >= charIdx + charsForDefault.length) ? -1 : 0);
        }, glyphChar.bWidth);
        deleteGlyph.color = FlxColor.RED;
        deleteGlyph.selectable = false;
        glyphCreateWindow.members.push(deleteGlyph);

        infoWindow = new GlyphInfoWindow();
        uiGroup.add(infoWindow);

        // --- Components ---
        componentList = new UIButtonList<ComponentButton>(0, 720 - 170 - 30, 230, 170, "Components:", FlxPoint.get(230, 50), FlxPoint.get(0, 0), 0);
        componentList.dragCallback = (button, oldID, newID) -> queueReorder = true;
        componentList.addButton.callback = () -> {
            curSelectedComponent = {
                anim: "", x:0, y:0,
                shouldRotate:false, angle:0, sin:0, cos:1,
                scaleX:1, scaleY:1,
                flipX:false, flipY:false,
                hasColorMode:false, colorMode: bigLetter.colorMode
            };
            curSelectedData.components.push(curSelectedComponent);
            var newButton = new ComponentButton(curSelectedComponent);
            componentList.add(newButton);
            newButton.ID = componentList.buttons.members.length - 1;
            findOutline();
            infoWindow.updateInfo();
        };

        updateTape();
        uiGroup.add(componentList);

        add(topMenuSpr);
        add(uiGroup);

        if (Framerate.isLoaded) {
            Framerate.fpsCounter.alpha = 0.4;
            Framerate.memoryCounter.alpha = 0.4;
            Framerate.codenameBuildField.alpha = 0.4;
        }

        DiscordUtil.call("onEditorLoaded", ["Alphabet Editor", __typeface]);
    }

    // --- Other functions stay mostly unchanged ---
    // destroy(), update(), updateTape(), changeLetter(), findOutline(), checkForFailed()
    // _tape_left(), _tape_right(), buildAlphabet(), _file_save(), _file_saveas(), _file_exit(), _edit_main()
}

// ComponentButton class unchanged, only formatting fixed
class ComponentButton extends UIButton {
    public var component:AlphabetComponent;
    public var selected:Bool = false;
    public var deleteButton:UIButton;
    public var deleteIcon:FlxSprite;

    public function new(component:AlphabetComponent) {
        super(0, 0, component.anim, function() {
            AlphabetEditor.instance.curSelectedComponent = component;
            AlphabetEditor.instance.findOutline();
            AlphabetEditor.instance.infoWindow.updateInfo();
        }, 230, 50);
        this.component = component;

        deleteButton = new UIButton(bWidth - 32 - 10, 0, "", function() {
            var data = AlphabetEditor.instance.curSelectedData;
            var outlineDrop = (component.outIndex != null) ? 1 : 0;
            var componentIndex = data.components.indexOf(component);

            for (i in 0...data.components.length) {
                var nextCompon = data.components[i];
                var anim = AlphabetEditor.instance.bigLetter.text + i;
                AlphabetEditor.instance.bigLetter.animation.remove(anim);
                AlphabetEditor.instance.tape.animation.remove(anim);

                if (i > componentIndex && nextCompon.outIndex != null) {
                    --data.components[nextCompon.outIndex].refIndex;
                    nextCompon.outIndex -= outlineDrop;
                }
            }

            if (component.outIndex != null) {
                data.components.splice(component.outIndex, 1);
                --data.startIndex;
            }

            data.components.remove(component);
            AlphabetEditor.instance.curSelectedComponent = AlphabetEditor.instance.curSelectedComponent == component ? null : AlphabetEditor.instance.curSelectedComponent;
            AlphabetEditor.instance.findOutline();
            AlphabetEditor.instance.infoWindow.updateInfo();

            AlphabetEditor.instance.componentList.remove(this);
        }, 32);
        deleteButton.color = FlxColor.RED;
        deleteButton.autoAlpha = false;
        members.push(deleteButton);

        deleteIcon = new FlxSprite(deleteButton.x + 7, deleteButton.y + 8).loadGraphic(Paths.image("editors/delete-button"));
        deleteIcon.antialiasing = false;
        members.push(deleteIcon);
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        deleteButton.y = y + 10;
        deleteIcon.x = deleteButton.x + 7;
        deleteIcon.y = deleteButton.y + 8;
    }
}
