extends SceneTree

# Run with: godot --headless --path . --script res://tests/save_test.gd
const TEST_PROFILES := "user://test_save_profiles.cfg"
const TEST_DIR := "user://test_saves"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func run() -> void:
	var profiles = root.get_node("Profiles")
	var save_game = root.get_node("SaveGame")
	var wallet = root.get_node("Wallet")
	var mailbox = root.get_node("Mailbox")
	var jobs = root.get_node("Jobs")
	profiles.path = TEST_PROFILES
	save_game.directory = TEST_DIR
	profiles.reset()
	jobs.mail_delay = 0.2

	profiles.create("Alex")
	profiles.create("Sam")
	var alex: Dictionary = profiles.find("Alex")
	check(alex.id != profiles.find("Sam").id, "every user gets their own save id")

	profiles.log_in("Alex")
	check(save_game.has_save(alex.id), "a new user gets a save file right away")
	check(wallet.balance == wallet.START_BALANCE and mailbox.inbox.is_empty(), "a new user starts a new game")
	wallet.withdraw(250, "Groceries")
	jobs.apply(load("res://data/jobs/tinysoft_qa.tres"))
	await create_timer(0.4).timeout
	check(mailbox.inbox.size() == 1, "the trial letter arrives")
	mailbox.set_read(mailbox.inbox[0], true)
	var welcome: MailMessage = load("res://data/mail/welcome.tres")
	check(mailbox.deliver_once(welcome) and not mailbox.deliver_once(welcome), "a story letter is delivered only once")
	mailbox.set_read(mailbox.inbox[0], true)
	var trial_uuid: String = jobs.assignments.keys()[0]
	jobs.find(trial_uuid).set_mark(jobs.find(trial_uuid).checks[0], QaAssignment.Mark.FAIL)
	# Submitting a trial queues a letter that must survive the save.
	var trial: QaAssignment = jobs.find(trial_uuid)
	for id in trial.checks:
		trial.set_mark(id, QaAssignment.Mark.FAIL if trial.bugs.has(id) else QaAssignment.Mark.PASS)
	jobs.mail_delay = 60.0
	jobs.submit(trial)
	check(save_game.save(), "progress is written")

	profiles.log_in("Sam")
	check(wallet.balance == wallet.START_BALANCE and mailbox.inbox.is_empty() and jobs.assignments.is_empty(), "another user does not see Alex's progress")
	check(not mailbox.was_sent(welcome), "another user still gets the story letters")

	profiles.load_users()
	profiles.log_in("Alex")
	check(wallet.balance == wallet.START_BALANCE - 250 + jobs.TRIAL_REWARD, "balance is restored")
	check(wallet.history.size() == 3 and wallet.history[1].title == "Groceries", "bank history is restored")
	check(mailbox.inbox.size() == 2 and mailbox.inbox[1].read and mailbox.inbox[1].subject.containsn("test assignment"), "letters and their read state are restored")
	check(mailbox.was_sent(welcome) and not mailbox.deliver_once(welcome), "a story letter is not sent again after loading")
	check(jobs.status(jobs.QA_LISTING) == jobs.Status.HIRED, "employment is restored")
	var restored: QaAssignment = jobs.find(trial_uuid)
	check(restored != null and restored.submitted and restored.passed and restored.marks.size() == restored.checks.size(), "QA tasks and marks are restored")
	check(jobs.save_state().pending.size() == 1, "the letter that was on its way is still on its way")

	profiles.reset()
	check(not DirAccess.dir_exists_absolute(TEST_DIR) or DirAccess.get_files_at(TEST_DIR).is_empty(), "reset deletes every save file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
