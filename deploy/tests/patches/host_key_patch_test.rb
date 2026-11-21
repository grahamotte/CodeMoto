require_relative "../test_helper"

class HostKeyPatchTest < Minitest::Test
  def test_needed_only_when_the_droplet_presents_another_host_key
    Cmd.expects(:ssh).with("true", quiet: true).returns("")
    refute HostKeyPatch.needed?

    Cmd.expects(:ssh).with("true", quiet: true).raises(Net::SSH::HostKeyMismatch)
    assert HostKeyPatch.needed?

    Cmd.expects(:ssh).with("true", quiet: true).raises(Net::SSH::AuthenticationFailed)
    refute HostKeyPatch.needed?
  end

  def test_apply_installs_the_pinned_key_over_the_known_host_key
    sequence = sequence("host key")
    Cmd.expects(:ssh)
      .with("sudo install -m 600 -o root -g root /dev/stdin /etc/ssh/ssh_host_ed25519_key", stdin: DeployTestHostKey.private_key, host_key: :known_hosts)
      .in_sequence(sequence)
    Cmd.expects(:ssh)
      .with("sudo install -m 644 -o root -g root /dev/stdin /etc/ssh/ssh_host_ed25519_key.pub", stdin: "#{DeployTestHostKey.public_key}\n", host_key: :known_hosts)
      .in_sequence(sequence)
    Cmd.expects(:ssh)
      .with("sudo find /etc/ssh -maxdepth 1 -name 'ssh_host_*' ! -name 'ssh_host_ed25519_key*' -delete", stdin: nil, host_key: :known_hosts)
      .in_sequence(sequence)
    Cmd.expects(:ssh)
      .with("sudo tee /etc/ssh/sshd_config > /dev/null", stdin: DeployUserPatch.sshd_conf, host_key: :known_hosts)
      .in_sequence(sequence)
    Cmd.expects(:ssh)
      .with("sudo sshd -t && sudo systemctl restart ssh", stdin: nil, host_key: :known_hosts)
      .in_sequence(sequence)
    Cmd.expects(:ssh).with("true").in_sequence(sequence)

    HostKeyPatch.apply
  end

  def test_apply_refuses_an_unknown_host_key
    Req.stubs(:call).returns(droplets: [ { name: "example.com", status: "active", networks: { v4: [ { type: "public", ip_address: "1.2.3.4" } ] } } ])
    Cmd.expects(:ssh).with(anything, stdin: anything, host_key: :known_hosts).raises(Net::SSH::HostKeyUnknown).once

    error = assert_raises(RuntimeError) { HostKeyPatch.apply }

    assert_includes error.message, "1.2.3.4 is not in ~/.ssh/known_hosts"
  end
end
