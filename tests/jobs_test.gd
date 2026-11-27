extends SceneTree

# Run with: godot --headless --path . --script res://tests/jobs_test.gd
# Jobs.Status values; job_board.gd uses autoloads, so it cannot be preloaded here.
const APPLIED := 1
const HIRED := 2
const FIRED := 3
var failures := 0
var jobs: Node
var wallet: Node
var mailbox: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

## Marks every check of the assignment through the DEBUG rows; `correct` decides whether the report is right.
func fill_report(debug: Control, assignment: QaAssignment, correct: bool) -> void:
	var first := true
	for row in debug.rows.get_children():
		var broken: bool = assignment.bugs.has(row.check)
		if not correct and first:
			broken = not broken
		first = false
		row.pressed.emit()
		if broken:
			row.pressed.emit()

func run() -> void:
	load("res://scripts/apps/browser.gd").instant_loading = true
	jobs = root.get_node("Jobs")
	wallet = root.get_node("Wallet")
	mailbox = root.get_node("Mailbox")
	jobs.mail_delay = 0.05

	# Assignment generation.
	var rng := RandomNumberGenerator.new()
	var uuid_shape := RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	var seen := {}
	var bug_counts_ok := true
	for i in 200:
		var task := QaAssignment.create(1000 + i, false, 100, rng)
		seen[task.uuid] = true
		bug_counts_ok = bug_counts_ok and task.checks.size() == 10 and task.bugs.size() >= 1 and task.bugs.size() <= 3
		bug_counts_ok = bug_counts_ok and uuid_shape.search(task.uuid) != null
	check(bug_counts_ok, "regular tasks have 10 checks, 1–3 bugs and a v4 UUID")
	check(seen.size() == 200, "every task gets a new UUID")
	var trial := QaAssignment.create(0, true, 50, rng)
	check(trial.checks.size() == 3 and trial.bugs.size() == 1 and trial.bugs.has(trial.bugs.keys()[0]) and trial.checks.has(trial.bugs.keys()[0]), "trial has 3 checks with exactly one bug among them")

	var desktop = load("res://scenes/desktop.tscn").instantiate()
	# The story letters would mix with the job letters this test counts.
	desktop.get_node("IntroMail").letters.clear()
	root.add_child(desktop)
	await process_frame

	# Job board.
	desktop._open_site("stupidjob.oc")
	await process_frame
	var browser = desktop.manager.windows["browser"].content
	var cards: Array = browser.page.get_node("%Listings").get_children()
	check(cards.size() == 1, "stupidjob.oc lists one vacancy")
	var card = cards[0]
	check(card.get_node("%Title").text.containsn("QA Tester") and card.get_node("%Pay").text == "$100 per task", "vacancy is the $100 per task QA tester job")
	check(card.get_node("%Apply").text == "Apply now" and not card.get_node("%Apply").disabled, "vacancy has an Apply now button")
	card.get_node("%Apply").pressed.emit()
	check(jobs.status("tinysoft_qa") == APPLIED and card.get_node("%Apply").disabled, "applying marks the vacancy as applied")
	check(mailbox.inbox.is_empty(), "the test assignment is not delivered instantly")
	await wait(0.2)
	check(mailbox.inbox.size() == 1, "the test assignment arrives by mail")
	var letter: MailMessage = mailbox.inbox[0]
	var trial_task: QaAssignment = jobs.assignments.values()[0]
	check(trial_task.trial and letter.body.contains("tinysoft.test.oc/" + trial_task.uuid), "the letter links to the trial session")
	check(desktop.get_node("%Notifications").get_child_count() > 0, "new mail shows a desktop notification")

	# The mail app shows the letter and its link opens the store and DEBUG window.
	desktop._open("mail")
	await process_frame
	var mail = desktop.manager.windows["mail"].content
	check(mail.messages[0] == letter, "the Mail app lists the delivered letter first")
	mail.get_node("%Body").meta_clicked.emit(trial_task.link())
	await process_frame
	check(browser.address.text == trial_task.link(), "the browser opens the session link")
	check(desktop.manager.windows.has("qa_debug"), "the DEBUG window opens with the test site")
	var debug = desktop.manager.windows["qa_debug"].content
	check(debug.rows.get_child_count() == 3, "DEBUG lists the 3 trial checks")
	check(debug.submit.disabled, "SUBMIT waits until every check is marked")

	# Marks cycle: none -> works -> broken.
	var row = debug.rows.get_child(0)
	row.pressed.emit()
	check(trial_task.mark(row.check) == QaAssignment.Mark.PASS, "first click marks a check as working")
	row.pressed.emit()
	check(trial_task.mark(row.check) == QaAssignment.Mark.FAIL, "second click marks it as broken")
	row.pressed.emit()
	check(trial_task.mark(row.check) == QaAssignment.Mark.NONE, "third click clears it")

	# Store behaviour with and without bugs.
	var shop = browser.page
	shop.assignment = QaAssignment.new()
	shop.cart.clear()
	shop.get_node("%Grid/mouse/Stack/Add").pressed.emit()
	check(shop.cart.get("mouse", 0) == 1 and shop.get_node("%Tabs/cart").text == "Cart (1)", "a working Add to cart adds one item")
	shop.assignment.bugs["add_mouse"] = "double"
	shop.get_node("%Grid/mouse/Stack/Add").pressed.emit()
	check(shop.cart["mouse"] == 3, "a double-add bug adds two items")
	shop.assignment.bugs["tab_cart"] = "dead"
	shop.get_node("%Tabs/cart").pressed.emit()
	check(shop.section == "home", "a dead tab does nothing")
	shop.assignment.bugs["checkout"] = "crash"
	shop.get_node("%Sections/cart/Stack/Actions/Checkout").pressed.emit()
	check(shop.get_node("%Error").visible and shop.cart["mouse"] == 3, "a crashing checkout shows an error and keeps the cart")
	shop.assignment = trial_task

	# Correct trial report: $50, hired, next task by mail.
	var before: int = wallet.balance
	fill_report(debug, trial_task, true)
	check(not debug.submit.disabled, "SUBMIT unlocks when every check is marked")
	debug.submit.pressed.emit()
	check(wallet.balance == before + 50, "a correct trial pays $50")
	check(jobs.status("tinysoft_qa") == HIRED, "a correct trial hires the player")
	await wait(0.2)
	check(mailbox.inbox.size() == 2 and mailbox.inbox[0].subject.containsn("offer"), "the hiring letter arrives")
	var task: QaAssignment = jobs.find(mailbox.inbox[0].body.get_slice("tinysoft.test.oc/", 1).left(36))
	check(task != null and not task.trial and task.uuid != trial_task.uuid, "the hiring letter carries a new task with a new UUID")
	desktop._open_site("tinysoft.test.oc/" + trial_task.uuid)
	await process_frame
	check(browser.page.get_node("%Denied").visible, "a submitted session is closed")

	# Regular task: correct pays $100, wrong pays nothing but the work continues.
	desktop._open_site(task.link())
	await process_frame
	check(debug.rows.get_child_count() == 10, "regular tasks list 10 checks")
	before = wallet.balance
	fill_report(debug, task, true)
	debug.submit.pressed.emit()
	check(wallet.balance == before + 100, "a correct report pays $100")
	await wait(0.2)
	var next: QaAssignment = jobs.find(mailbox.inbox[0].body.get_slice("tinysoft.test.oc/", 1).left(36))
	check(mailbox.inbox[0].subject.containsn("accepted") and next != null, "acceptance letter brings the next task")
	desktop._open_site(next.link())
	await process_frame
	before = wallet.balance
	fill_report(debug, next, false)
	debug.submit.pressed.emit()
	check(wallet.balance == before, "a wrong report pays nothing")
	check(jobs.status("tinysoft_qa") == HIRED, "a wrong regular report does not fire the player")
	await wait(0.2)
	check(mailbox.inbox[0].subject.containsn("rejected"), "rejection letter arrives with the next task")

	# Failed trial fires the player.
	jobs.statuses.clear()
	jobs.apply(load("res://data/jobs/tinysoft_qa.tres"))
	await wait(0.2)
	var second_trial: QaAssignment = jobs.find(mailbox.inbox[0].body.get_slice("tinysoft.test.oc/", 1).left(36))
	desktop._open_site(second_trial.link())
	await process_frame
	before = wallet.balance
	fill_report(debug, second_trial, false)
	debug.submit.pressed.emit()
	check(wallet.balance == before and jobs.status("tinysoft_qa") == FIRED, "a failed trial pays nothing and fires the player")
	await wait(0.2)
	check(mailbox.inbox[0].body.containsn("terminated"), "the player is told they were let go")
	desktop._open_site("stupidjob.oc")
	await process_frame
	var closed = browser.page.get_node("%Listings").get_child(0)
	check(closed.get_node("%Apply").disabled and closed.get_node("%Apply").text == "Position closed", "the vacancy is closed after being fired")

	desktop.queue_free()
	# Bank sounds still playing are released by the audio server on its next mix.
	await create_timer(0.3).timeout
	quit(failures)
