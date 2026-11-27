class_name QaAssignment
extends RefCounted

## One TinySoft QA task: a fresh test build of the shop at tinysoft.test.oc/{uuid}
## with a checklist of controls, some of which are secretly broken.
##
## The player marks every check as working or broken in the DEBUG window; the report
## passes only when every mark matches the hidden bug list.

enum Mark { NONE, PASS, FAIL }

const HOST := "tinysoft.test.oc"
const TRIAL_CHECKS := 3
const TRIAL_BUGS := 1
const MIN_BUGS := 1
const MAX_BUGS := 3

## Every control on the shop that can be put on a checklist, in checklist order.
## The prefix before "_" is the control kind and decides which bugs it can have.
const CHECKS := {
	"tab_home": "Header tab “Home” opens the home page",
	"tab_catalog": "Header tab “Catalog” opens the product catalog",
	"tab_cart": "Header tab “Cart” opens the shopping cart",
	"tab_contacts": "Header tab “Contacts” opens the contacts page",
	"add_mouse": "“Add to cart” adds one Wireless Mouse",
	"add_keyboard": "“Add to cart” adds one Compact Keyboard",
	"add_lamp": "“Add to cart” adds one Desk Lamp",
	"add_mug": "“Add to cart” adds one Coffee Mug",
	"clear_cart": "“Clear cart” removes every item from the cart",
	"checkout": "“Checkout” places the order for the cart total",
}

## Ways each kind of control can misbehave.
const BUGS := {
	"tab": ["dead", "wrong", "crash"],
	"add": ["dead", "wrong", "double", "crash"],
	"clear": ["dead", "partial", "crash"],
	"checkout": ["dead", "wrong", "crash"],
}

var uuid := ""
var number := 0
var trial := false
var reward := 0
var checks: Array[String] = []
## check id -> bug kind, only for the broken checks.
var bugs: Dictionary[String, String] = {}
## check id -> Mark, as reported by the player.
var marks: Dictionary[String, int] = {}
## Extra dollars a "wrong" checkout adds to the total, fixed for the whole session.
var overcharge := 0
var submitted := false
var passed := false

static func create(task_number: int, is_trial: bool, task_reward: int, rng: RandomNumberGenerator) -> QaAssignment:
	var assignment := QaAssignment.new()
	assignment.uuid = new_uuid(rng)
	assignment.number = task_number
	assignment.trial = is_trial
	assignment.reward = task_reward
	assignment.overcharge = rng.randi_range(4, 19)
	var pool: Array[String] = []
	pool.assign(CHECKS.keys())
	var picked := pool.duplicate()
	_shuffle(picked, rng)
	if is_trial:
		picked.resize(TRIAL_CHECKS)
	# Keep the checklist in the shop's natural order.
	for id in pool:
		if picked.has(id):
			assignment.checks.append(id)
	var broken_count := TRIAL_BUGS if is_trial else rng.randi_range(MIN_BUGS, MAX_BUGS)
	var broken := assignment.checks.duplicate()
	_shuffle(broken, rng)
	for id: String in broken.slice(0, broken_count):
		var options: Array = BUGS[kind_of(id)]
		assignment.bugs[id] = options[rng.randi_range(0, options.size() - 1)]
	return assignment

## Random version-4 UUID, e.g. "3f6c1a9e-52b7-4d0e-9a41-07c2b8e5d913".
static func new_uuid(rng: RandomNumberGenerator) -> String:
	var bytes: Array[int] = []
	for i in 16:
		bytes.append(rng.randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := ""
	for i in 16:
		if i in [4, 6, 8, 10]:
			hex += "-"
		hex += "%02x" % bytes[i]
	return hex

## Plain data for the save file.
func to_dict() -> Dictionary:
	return {
		"uuid": uuid, "number": number, "trial": trial, "reward": reward,
		"checks": Array(checks), "bugs": Dictionary(bugs), "marks": Dictionary(marks),
		"overcharge": overcharge, "submitted": submitted, "passed": passed,
	}

static func from_dict(data: Dictionary) -> QaAssignment:
	var assignment := QaAssignment.new()
	assignment.uuid = str(data.get("uuid", ""))
	assignment.number = int(data.get("number", 0))
	assignment.trial = bool(data.get("trial", false))
	assignment.reward = int(data.get("reward", 0))
	assignment.overcharge = int(data.get("overcharge", 0))
	assignment.submitted = bool(data.get("submitted", false))
	assignment.passed = bool(data.get("passed", false))
	for id in data.get("checks", []):
		assignment.checks.append(str(id))
	var saved_bugs: Dictionary = data.get("bugs", {})
	for id in saved_bugs:
		assignment.bugs[str(id)] = str(saved_bugs[id])
	var saved_marks: Dictionary = data.get("marks", {})
	for id in saved_marks:
		assignment.marks[str(id)] = int(saved_marks[id])
	return assignment

static func kind_of(check: String) -> String:
	return check.get_slice("_", 0)

static func caption_of(check: String) -> String:
	return CHECKS.get(check, check)

func link() -> String:
	return HOST + "/" + uuid

## "#1042" for regular tasks, "trial" for the test assignment.
func title() -> String:
	return "trial" if trial else "#%d" % number

func bug(check: String) -> String:
	return bugs.get(check, "")

func mark(check: String) -> Mark:
	return marks.get(check, Mark.NONE) as Mark

func set_mark(check: String, value: Mark) -> void:
	if checks.has(check) and not submitted:
		marks[check] = value

func marked_count() -> int:
	return checks.filter(func(id: String): return mark(id) != Mark.NONE).size()

func is_complete() -> bool:
	return marked_count() == checks.size()

## Number of checks whose mark disagrees with the hidden bug list (unmarked counts as wrong).
func mistakes() -> int:
	var count := 0
	for id in checks:
		var expected := Mark.FAIL if bugs.has(id) else Mark.PASS
		if mark(id) != expected:
			count += 1
	return count

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = items[i]
		items[i] = items[j]
		items[j] = swap
