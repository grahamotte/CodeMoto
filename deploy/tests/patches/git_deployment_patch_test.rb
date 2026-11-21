require_relative "../test_helper"

class GitDeploymentPatchTest < Minitest::Test
  def test_existing_deployment
    Req.expects(:call).returns(droplets: [ active_instance ])
    local = []
    remote = []
    Cmd.stubs(:local).with { |command, *| local << command; true }.returns("abc123\n")
    Cmd.stubs(:ssh).with { |command, *| remote << command; true }.returns("")

    GitDeploymentPatch.always

    assert local.any? { |command| command.include?("git remote add deployment deploy@1.2.3.4:") }
    assert_includes local, "git fetch origin master"
    assert_includes local, "git rev-parse origin/master"
    assert local.any? { |command| command.end_with?("git push --force deployment abc123:refs/heads/master") }
    pushes = local.select { |command| command.include?("GIT_SSH_COMMAND=") }
    refute_empty pushes
    assert pushes.all? { |command| command.start_with?("GIT_SSH_COMMAND=#{Shellwords.escape(Cmd.ssh_command)} ") }
    refute local.any? { |command| command.include?("git push deployment master") }
    assert_includes remote, "sudo mkdir -p /var/www/example.com"
    assert_includes remote, "sudo chown deploy:deploy /var/www/example.com"
    assert_includes remote, "cd /var/www/example.com && git fetch"
    assert_includes remote, "cd /var/www/example.com && git checkout -- ."
    assert_includes remote, "cd /var/www/example.com && git reset --hard origin/master"
    refute local.any? { |command| command.include?("git clone --bare") }
  end

  def test_missing_deployment
    Req.expects(:call).returns(droplets: [ active_instance ])
    local = []
    remote = []
    Cmd.stubs(:local).with { |command, *| local << command; true }.returns("abc123\n")
    Cmd.stubs(:ssh).with do |command, *|
      remote << command
      !command.start_with?("[ -d")
    end.returns("")
    Cmd.stubs(:ssh).with { |command, *| command.start_with?("[ -d") }.raises("missing")

    GitDeploymentPatch.always

    refute local.any? { |command| command.include?("ssh-keyscan") || command.include?("ssh-keygen") }
    assert_includes local, "rsync -av -e #{Shellwords.escape(Cmd.ssh_command)} #{Constants.local_git_dir}/ deploy@1.2.3.4:#{Constants.remote_git_dir}/"
    assert local.any? { |command| command.include?("git clone --bare #{Constants.local_root}") }
    assert remote.any? { |command| command == "git clone #{Constants.remote_git_dir} #{Constants.remote_root}" }
  end

  private

  def active_instance
    {
      name: "example.com",
      status: "active",
      networks: { v4: [ { type: "public", ip_address: "1.2.3.4" } ] },
    }
  end
end
