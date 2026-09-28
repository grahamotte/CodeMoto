require_relative "test_helper"

class TriggerAllTest < Minitest::Test
  def test_triggers_current_repo_and_siblings_with_the_task
    current = add_repo(File.basename(Worktree.root))
    other = add_repo("other.org")
    FileUtils.mkdir_p(File.join(parent, "plain"))
    commands = stub_mise

    output, = capture_io { TriggerAll.call }

    assert_equal [ current, other ].sort, commands.map { |command| command[:directory] }
    assert_equal report(ran: [ "other.org", "repo" ]), output
    assert commands.all? { |command| command[:args] == [ "mise", "manager:trigger" ] }
  end

  def test_warns_when_code_moto_repo_lacks_the_task
    add_repo("nozsig.com", toml: "[tasks.\"manager:sync\"]\nrun = \"true\"\n")
    add_repo("badgeonbar.com", toml: "[tasks.\"manager:sync\"]\nrun = \"true\"\n")
    add_repo("alpha.org")
    commands = stub_mise

    output, = capture_io { TriggerAll.call }

    assert_equal [ "alpha.org" ], commands.map { |command| File.basename(command[:directory]) }
    assert_equal report(
      ran: [ "alpha.org" ],
      skipped: [ "badgeonbar.com", "nozsig.com" ],
      warnings: [
        "skipping badgeonbar.com: no manager:trigger task (merge latest Code Moto)",
        "skipping nozsig.com: no manager:trigger task (merge latest Code Moto)",
      ],
    ), output
  end

  def test_skips_non_code_moto_repos_quietly
    add_repo("app.org", toml: "[tasks.\"build\"]\nrun = \"true\"\n")
    FileUtils.mkdir_p(File.join(parent, "plain"))
    commands = stub_mise

    output, = capture_io { TriggerAll.call }

    assert_empty commands
    assert_equal report, output
  end

  def test_skips_worktrees
    add_repo("app.org")
    add_worktree("app.org-moto-1", toml: "[tasks.\"manager:sync\"]\nrun = \"true\"\n")
    commands = stub_mise

    output, = capture_io { TriggerAll.call }

    assert_equal [ File.join(parent, "app.org") ], commands.map { |command| command[:directory] }
    assert_equal report(ran: [ "app.org" ]), output
    refute_includes output, "app.org-moto-1"
  end

  def test_runs_in_sorted_order
    add_repo("zeta.org")
    add_repo("alpha.org")
    commands = stub_mise

    output, = capture_io { TriggerAll.call }

    assert_equal [ "alpha.org", "zeta.org" ], commands.map { |command| File.basename(command[:directory]) }
    assert_equal report(ran: [ "alpha.org", "zeta.org" ]), output
  end

  def test_prints_trigger_output
    add_repo("app.org")
    stub_mise(stdout: "started working on APP-1\n")

    output, = capture_io { TriggerAll.call }

    assert_equal report(ran: [ "app.org" ], body: "started working on APP-1\n"), output
  end

  def test_separates_summary_from_trigger_output_without_a_trailing_newline
    add_repo("app.org")
    stub_mise(stdout: "started working on APP-1")

    output, = capture_io { TriggerAll.call }

    assert_equal report(ran: [ "app.org" ], body: "started working on APP-1\n"), output
  end

  def test_raises_when_trigger_fails
    add_repo("alpha.org")
    add_repo("zeta.org")
    commands = stub_mise(stderr: "boom", success: false)

    output, err = capture_io do
      error = assert_raises(RuntimeError) { TriggerAll.call }
      assert_equal "mise manager:trigger failed in #{File.join(parent, "alpha.org")}: boom", error.message
    end

    assert_equal [ "alpha.org" ], commands.map { |command| File.basename(command[:directory]) }
    assert_equal "==> alpha.org\n", output
    assert_equal "boom", err
  end

  def test_uses_stdout_when_stderr_is_blank
    add_repo("app.org")
    stub_mise(stdout: "failed", success: false)

    error = assert_raises(RuntimeError) { capture_io { TriggerAll.call } }

    assert_equal "mise manager:trigger failed in #{File.join(parent, "app.org")}: failed", error.message
  end

  def test_directories_lists_triggerable_repos
    current = add_repo(File.basename(Worktree.root))
    other = add_repo("other.org")
    add_repo("skip.org", toml: "")
    add_repo("stale.org", toml: "[tasks.\"manager:sync\"]\nrun = \"true\"\n")
    add_worktree("other.org-moto-1")

    assert_equal [ current, other ].sort, TriggerAll.directories
  end

  private

  def parent
    File.expand_path("..", Worktree.root)
  end

  def add_repo(name, toml: "[tasks.\"manager:trigger\"]\nrun = \"true\"\n")
    path = File.join(parent, name)
    FileUtils.mkdir_p(File.join(path, ".git"))
    File.write(File.join(path, "mise.toml"), toml)
    path
  end

  def add_worktree(name, toml: "[tasks.\"manager:trigger\"]\nrun = \"true\"\n")
    path = add_repo(name, toml:)
    FileUtils.rm_rf(File.join(path, ".git"))
    File.write(File.join(path, ".git"), "gitdir: /tmp/git")
    path
  end

  def stub_mise(stdout: "", stderr: "", success: true)
    commands = []
    status = Object.new
    status.define_singleton_method(:success?) { success }
    Open3.stubs(:capture3).with do |*args, **kwargs|
      commands << { args:, directory: kwargs[:chdir] }
      true
    end.returns([ stdout, stderr, status ])
    commands
  end

  def report(ran: [], skipped: [], warnings: [], body: "")
    headers = ran.map { |name| "==> #{name}\n" }.join
    warning_lines = warnings.map { |warning| "#{warning}\n" }.join
    "#{warning_lines}#{headers}#{body}ran: #{ran.join(", ")}\nskipped: #{skipped.join(", ")}\n"
  end
end
