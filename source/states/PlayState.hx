package states;

import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import cutscenes.DialogueBoxPsych;

import states.StoryMenuState;
import states.FreeplayState;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.PauseSubState;
import substates.GameOverSubstate;

#if !flash
import openfl.filters.ShaderFilter;
#end

import shaders.ErrorHandledShader;

import objects.VideoSprite;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.HScriptInfos;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], 
		['Shit', 0.4], 
		['Bad', 0.5], 
		['Bruh', 0.6], 
		['Meh', 0.69], 
		['Nice', 0.7], 
		['Great', 0.8], 
		['Amazing', 0.9], 
		['INCREDIBLE', 1], 
		['OUTSTANDING!!!!!', 1] 
	];

	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var curStage:String = '';
	public static var stageUI(default, set):String = "normal";
	public static var uiPrefix:String = "";
	public static var uiPostfix:String = "";
	public static var isPixelStage(get, never):Bool;

	@:noCompletion
	static function set_stageUI(value:String):String
	{
		uiPrefix = uiPostfix = "";
		if (value != "normal")
		{
			uiPrefix = value.split("-pixel")[0].trim();
			if (value == "pixel" || value.endsWith("-pixel")) uiPostfix = "-pixel";
		}
		return stageUI = value;
	}

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 2000;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health(default, set):Float = 1;
	public var combo:Int = 0;

	public var healthBar:Bar;
	public var timeBar:Bar;
	var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;
	
	// Custom SB Engine HUD UI Elements & Persistent Tracking Counters
	public static var sbWatermark:FlxText;
	var sbMetaDataTxt:FlxText;
	var customHealthInfo:FlxText;
	var missWarning:FlxText;
	
	var continuousHighScore:Int = 0;
	var bestHitMilliseconds:Float = 999.0;
	var maxNpsRecord:Int = 0;
	var missWarningScaleTimer:Float = 0;

	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;

	public var guitarHeroSustains:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;
	public var pressMissDamage:Float = 0.05;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	public static var instance:PlayState;
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end
	public var introSoundsSuffix:String = '';

	private var keysArray:Array<String>;
	public var songName:String;

	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	override function create()
	{
		instance = this;
		super.create();
	}

	function createPost()
	{
		// 1. Core Bottom-Left Metadata Field Setup
		sbMetaDataTxt = new FlxText(12, FlxG.height - 24, 0, "", 16);
		sbMetaDataTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		sbMetaDataTxt.scrollFactor.set();
		sbMetaDataTxt.borderSize = 1.25;
		sbMetaDataTxt.cameras = [camHUD];
		sbMetaDataTxt.visible = !ClientPrefs.data.hideHud;
		add(sbMetaDataTxt);

		// 2. Custom Live Health Tracker Object Setup
		customHealthInfo = new FlxText(20, 20, 1280, "Health: 50%", 20);
		customHealthInfo.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		customHealthInfo.scrollFactor.set();
		customHealthInfo.borderSize = 1.25;
		customHealthInfo.cameras = [camHUD];
		customHealthInfo.visible = !ClientPrefs.data.hideHud;
		add(customHealthInfo);

		// 3. Screen-Centered Miss Warning Popup Setup
		missWarning = new FlxText(0, 0, 1280, "Miss!", 40);
		missWarning.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.RED, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missWarning.scrollFactor.set();
		missWarning.borderSize = 2;
		missWarning.cameras = [camHUD];
		missWarning.screenCenter();
		missWarning.alpha = 0;
		add(missWarning);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// 1. Live Frame Update Calculations for Adaptive Health Percentage Display
		if (customHealthInfo != null && !cpuControlled) {
			var currentHealth:Int = Std.int(Math.max(0, Math.min(100, Math.floor((health / 2) * 100))));
			customHealthInfo.text = "Health: " + currentHealth + "%";

			if (currentHealth >= 75)
				customHealthInfo.color = FlxColor.GREEN;
			else if (currentHealth < 25)
				customHealthInfo.color = FlxColor.RED;
			else
				customHealthInfo.color = FlxColor.WHITE;
		}

		// 2. Clear Visual Popups and Decay Opacity Alpha Levels Frame-by-Frame
		if (missWarning != null && missWarning.alpha > 0) {
			missWarning.alpha -= (elapsed / 0.5);
		}

		// 3. Scale-Timer Handler for the Miss Warning Bounce Elastic Animation Effect
		if (missWarningScaleTimer > 0) {
			missWarningScaleTimer -= elapsed;
			if (missWarningScaleTimer <= 0) {
				missWarning.scale.set(1, 1);
			}
		}

		// 4. Live Tracking Icon Rotation and Scaling Setup
		if (ClientPrefs.data.iconBopStyle == 'SB Engine (Bopping.lua)') {
			var lerpVal:Float = FlxMath.bound(elapsed * 10, 0, 1);
			iconP1.angle += (0 - iconP1.angle) * lerpVal;
			iconP2.angle += (0 - iconP2.angle) * lerpVal;
			iconP1.scale.x += (1 - iconP1.scale.x) * lerpVal;
			iconP1.scale.y += (1 - iconP1.scale.y) * lerpVal;
			iconP2.scale.x += (1 - iconP2.scale.x) * lerpVal;
			iconP2.scale.y += (1 - iconP2.scale.y) * lerpVal;
iconP1.updateHitbox();
iconP2.updateHitbox();
} else {
var mult:Float = FlxMath.lerp(1, iconP1.scale.x, FlxMath.bound(1 - (elapsed * 9), 0, 1));
iconP1.scale.set(mult, mult);
iconP1.updateHitbox();
var mult2:Float = FlxMath.lerp(1, iconP2.scale.x, FlxMath.bound(1 - (elapsed * 9), 0, 1));
iconP2.scale.set(mult2, mult2);
iconP2.updateHitbox();
}
}
function beatHit()
{
super.beatHit();
if (ClientPrefs.data.iconBopStyle == 'SB Engine (Bopping.lua)') {
var oppIconDir:Float = (curBeat % 2 == 0) ? -1 : 1;
iconP2.angle = oppIconDir * 25;
iconP1.angle = -oppIconDir * 25;
iconP2.scale.set(1.2, 1.3);
iconP1.scale.set(1.2, 1.3);
} else {
iconP1.scale.set(1.2, 1.2);
iconP2.scale.set(1.2, 1.2);
}
}
function goodNoteHit(note:Note)
{
continuousHighScore += songScore;
var noteMs:Float = Math.abs(note.strumTime - Conductor.songPosition);
if (noteMs < bestHitMilliseconds && noteMs > 0) {
bestHitMilliseconds = noteMs;
}
}
function noteMiss(note:Note)
{
// Break the highscore combo string instantly
continuousHighScore = 0;
// Trigger Screen Center Notification Elastic Animation Bounces
if (missWarning != null) {
missWarning.alpha = 1;
missWarning.scale.set(1.3, 1.3);
missWarningScaleTimer = 0.05; // Recreates the 0.05s scale reset timer natively
}
}
function recalculateRating()
{
var displayAccuracy:Float = 0;
if (totalPlayed > 0) {
displayAccuracy = FlxMath.roundDecimal(ratingPercent * 100, 2);
}
if (backend.BaseStage.nps > maxNpsRecord) {
maxNpsRecord = backend.BaseStage.nps;
}
var msDisplay:String = (bestHitMilliseconds == 999.0) ? "0.00" : FlxMath.roundDecimal(bestHitMilliseconds, 2) + "ms";
// Update Custom Descriptive Layout Dashboard
scoreTxt.text = "High Score: " + continuousHighScore
+ " / Misses: " + songMisses
+ " / Accuracy: " + displayAccuracy + "%"
+ " / Average: " + msDisplay
+ " / Nps: " + backend.BaseStage.nps + "/" + maxNpsRecord;
var myGrade:String = "Null";
if (totalPlayed > 0) {
var acc:Float = ratingPercent * 100;
if (acc >= 99) myGrade = "S";
else if (acc >= 95) myGrade = "A";
else if (acc >= 90) myGrade = "B";
else if (acc >= 80) myGrade = "C";
else if (acc >= 70) myGrade = "D";
else if (acc >= 60) myGrade = "E";
else myGrade = "F";
}
var activeEngine:String = ClientPrefs.data.engineTheme;
var trackComposer:String = "Unknown";
if (PlayState.SONG.author != null && PlayState.SONG.author != "") {
trackComposer = PlayState.SONG.author;
}
if (sbMetaDataTxt != null) {
sbMetaDataTxt.text = PlayState.SONG.song + " | Grade: " + myGrade + " | Engine: " + activeEngine + " | Composer: " + trackComposer;
}
}
@:noCompletion
function set_health(value:Float):Float
{
return health = value;
}
@:noCompletion
function set_songSpeed(value:Float):Float
{
return songSpeed = value;
}
@:noCompletion
function set_playbackRate(value:Float):Float
{
return playbackRate = value;
}
}
