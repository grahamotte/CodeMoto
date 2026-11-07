require_relative "../test_helper"

class AppsBrewUpgradePatchTest < Minitest::Test
  INFO = "brew info --cask --json\\=v2 --installed"
  RUNNING = "osascript -e application\\ \\\"App\\\"\\ is\\ running"

  def test_upgrades_installed_cask_and_restarts_running_app
    configure
    commands = sequence("commands")
    Cmd.expects(:local).with(INFO).returns(JSON.generate(casks: [ { full_token: "grahamotte/tap/app" } ])).in_sequence(commands)
    Cmd.expects(:local).with(RUNNING).returns("true\n").in_sequence(commands)
    Cmd.expects(:local).with("brew update").returns("").in_sequence(commands)
    Cmd.expects(:local).with("brew upgrade --cask grahamotte/tap/app").returns("").in_sequence(commands)
    Cmd.expects(:local).with("osascript -e quit\\ app\\ \\\"App\\\"").returns("").in_sequence(commands)
    Cmd.expects(:local).with("open -a App").returns("").in_sequence(commands)

    assert Apps::BrewUpgradePatch.needed?
    Apps::BrewUpgradePatch.apply
  end

  def test_upgrades_without_reopening_app_that_was_not_running
    configure
    commands = sequence("commands")
    Cmd.expects(:local).with(RUNNING).returns("false\n").in_sequence(commands)
    Cmd.expects(:local).with("brew update").returns("").in_sequence(commands)
    Cmd.expects(:local).with("brew upgrade --cask grahamotte/tap/app").returns("").in_sequence(commands)

    Apps::BrewUpgradePatch.apply
  end

  def test_runs_brew_outside_bundler
    configure
    bundler = []
    Cmd.stubs(:local).with do |command|
      bundler << ENV["BUNDLE_GEMFILE"] if command.start_with?("brew")
      true
    end.returns("false\n")

    Apps::BrewUpgradePatch.apply

    assert_equal [ nil, nil ], bundler
  end

  def test_not_needed_when_cask_is_not_installed
    configure
    Cmd.expects(:local).with(INFO).returns(JSON.generate(casks: [ { full_token: "other/tap/app" }, { full_token: "app" } ]))

    refute Apps::BrewUpgradePatch.needed?
  end

  def test_not_needed_without_brew
    configure(brew: false)
    Cmd.expects(:local).never

    refute Apps::BrewUpgradePatch.needed?
  end

  def test_not_needed_without_homebrew_configuration_or_macos_target
    install_brew
    Cmd.expects(:local).never

    refute Apps::BrewUpgradePatch.needed?

    Apps.config[:homebrew] = { desc: "Does things", macos: "tahoe" }

    refute Apps::BrewUpgradePatch.needed?
  end

  def test_failed_upgrade_raises
    configure
    Cmd.stubs(:local).with { |command| command.start_with?("osascript") || command == "brew update" }.returns("false\n")
    Cmd.expects(:local).with("brew upgrade --cask grahamotte/tap/app").raises(RuntimeError, "Command failed")

    assert_raises(RuntimeError) { Apps::BrewUpgradePatch.apply }
  end

  private

  def configure(brew: true)
    target = Apps.targets.fetch(0)
    target[:name] = :macos
    target[:platform] = "MAC_OS"
    Apps.config[:homebrew] = { desc: "Does things", macos: "tahoe" }
    install_brew if brew
  end

  def install_brew
    path = File.join(@publish_test_dir, "bin", "brew")
    File.write(path, "")
    File.chmod(0755, path)
  end
end
