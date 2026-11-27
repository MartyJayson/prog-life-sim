extends Node

## Job applications and employment, registered as the `Jobs` autoload.
##
## TinySoft QA flow: apply on stupidjob.oc -> a trial task arrives by mail -> the player tests
## tinysoft.test.oc/{uuid} and submits the DEBUG report. A clean trial pays the trial fee and
## hires the player; a failed trial fires them. Each regular task pays its reward only when the
## report is fully correct, and the next task always follows by mail.
##
## Saved per user by the `SaveGame` autoload, including letters that are still on their way.

signal status_changed(listing_id: String)
## A test session was opened in the browser; the DEBUG window follows it.
signal assignment_opened(assignment: QaAssignment)
signal assignment_submitted(assignment: QaAssignment)
## Any change worth saving.
signal changed

enum Status { OPEN, APPLIED, HIRED, FIRED }

const QA_LISTING := "tinysoft_qa"
const TRIAL_REWARD := 50
const TASK_REWARD := 100
const FIRST_TASK_NUMBER := 1041
const LETTERS := {
	"trial": preload("res://data/mail/tinysoft_trial.tres"),
	"hired": preload("res://data/mail/tinysoft_hired.tres"),
	"fired": preload("res://data/mail/tinysoft_fired.tres"),
	"passed": preload("res://data/mail/tinysoft_passed.tres"),
	"failed": preload("res://data/mail/tinysoft_failed.tres"),
}

## Seconds between an action and the letter that answers it.
var mail_delay := 3.0
var statuses: Dictionary[String, int] = {}
var assignments: Dictionary[String, QaAssignment] = {}
## Session currently open in the browser.
var active: QaAssignment
var rng := RandomNumberGenerator.new()
var _next_number := FIRST_TASK_NUMBER
## Letters waiting to be sent: {"letter", "done", "next" (assignment uuids), "timer"}.
var _pending: Array[Dictionary] = []

func _ready() -> void:
	rng.randomize()

## No applications or tasks, as for a new user. Letters still on their way are dropped.
func reset_state() -> void:
	statuses.clear()
	assignments.clear()
	active = null
	_pending.clear()
	_next_number = FIRST_TASK_NUMBER

func save_state() -> Dictionary:
	var saved_assignments: Array[Dictionary] = []
	for assignment in assignments.values():
		saved_assignments.append(assignment.to_dict())
	var letters: Array[Dictionary] = []
	for entry in _pending:
		letters.append({
			"letter": entry.letter, "done": entry.done, "next": entry.next,
			"delay": maxf(entry.timer.time_left, 0.0),
		})
	return {
		"statuses": Dictionary(statuses), "assignments": saved_assignments,
		"next_number": _next_number, "pending": letters,
	}

func load_state(data: Dictionary) -> void:
	var saved_statuses: Dictionary = data.get("statuses", {})
	for id in saved_statuses:
		statuses[str(id)] = int(saved_statuses[id])
	for entry in data.get("assignments", []):
		if entry is Dictionary:
			var assignment := QaAssignment.from_dict(entry)
			assignments[assignment.uuid] = assignment
	_next_number = int(data.get("next_number", FIRST_TASK_NUMBER))
	for entry in data.get("pending", []):
		if entry is Dictionary and LETTERS.has(entry.get("letter", "")):
			_later(entry.letter, str(entry.get("done", "")), str(entry.get("next", "")), float(entry.get("delay", mail_delay)))

func status(listing_id: String) -> Status:
	return statuses.get(listing_id, Status.OPEN) as Status

func apply(listing: JobListing) -> bool:
	if status(listing.id) != Status.OPEN:
		return false
	_set_status(listing.id, Status.APPLIED)
	if listing.id == QA_LISTING:
		_later("trial", "", _issue(true).uuid)
	return true

func find(uuid: String) -> QaAssignment:
	return assignments.get(uuid.to_lower())

## Makes a session the active one, unless it is unknown or already submitted.
func open_assignment(uuid: String) -> QaAssignment:
	var assignment := find(uuid)
	if assignment == null or assignment.submitted:
		return null
	active = assignment
	assignment_opened.emit(assignment)
	return assignment

## Sends the DEBUG report. Pays and changes employment at once; the answer arrives by mail.
func submit(assignment: QaAssignment) -> bool:
	if assignment.submitted or not assignment.is_complete():
		return false
	assignment.submitted = true
	assignment.passed = assignment.mistakes() == 0
	if assignment.passed:
		Wallet.deposit(assignment.reward, "TinySoft — QA task %s" % assignment.title())
	assignment_submitted.emit(assignment)
	if assignment.trial and not assignment.passed:
		_set_status(QA_LISTING, Status.FIRED)
		_later("fired", assignment.uuid, "")
	elif assignment.trial:
		_set_status(QA_LISTING, Status.HIRED)
		_later("hired", assignment.uuid, _issue(false).uuid)
	else:
		_later("passed" if assignment.passed else "failed", assignment.uuid, _issue(false).uuid)
	changed.emit()
	return assignment.passed

func _issue(trial: bool) -> QaAssignment:
	var number := 0 if trial else _next_number
	if not trial:
		_next_number += 1
	var assignment := QaAssignment.create(number, trial, TRIAL_REWARD if trial else TASK_REWARD, rng)
	assignments[assignment.uuid] = assignment
	return assignment

func _send(letter: String, done: QaAssignment, next: QaAssignment) -> void:
	var message: MailMessage = LETTERS[letter].duplicate()
	var values := {
		"task": done.title() if done else "",
		"paid": Wallet.format_money(done.reward) if done else "",
		"mistakes": done.mistakes() if done else 0,
		"next_task": next.title() if next else "",
		"link": next.link() if next else "",
		"checks": next.checks.size() if next else 0,
		"reward": Wallet.format_money(next.reward) if next else "",
	}
	message.subject = message.subject.format(values)
	message.body = message.body.format(values)
	message.received = ""
	Mailbox.deliver(message)

func _set_status(listing_id: String, value: Status) -> void:
	statuses[listing_id] = value
	status_changed.emit(listing_id)
	changed.emit()

## Sends [param letter] after [param delay] seconds (by default `mail_delay`) unless the game
## state is reset first. Assignments are referenced by uuid so the wait survives a save.
func _later(letter: String, done_uuid: String, next_uuid: String, delay := -1.0) -> void:
	var entry := {
		"letter": letter, "done": done_uuid, "next": next_uuid,
		"timer": get_tree().create_timer(mail_delay if delay < 0.0 else delay),
	}
	_pending.append(entry)
	entry.timer.timeout.connect(_deliver_pending.bind(entry))

func _deliver_pending(entry: Dictionary) -> void:
	if not _pending.has(entry):
		return
	_pending.erase(entry)
	_send(entry.letter, find(entry.done), find(entry.next))
