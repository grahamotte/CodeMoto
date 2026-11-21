class HostKeyPatch < BasePatch
  class << self
    def needed?
      Cmd.ssh("true", quiet: true)
      false
    rescue Net::SSH::HostKeyMismatch
      true
    rescue StandardError
      false
    end

    def apply
      ssh("sudo install -m 600 -o root -g root /dev/stdin /etc/ssh/ssh_host_ed25519_key", stdin: Constants.ssh_host_key)
      ssh("sudo install -m 644 -o root -g root /dev/stdin /etc/ssh/ssh_host_ed25519_key.pub", stdin: "#{Constants.ssh_host_key_pub}\n")
      ssh("sudo find /etc/ssh -maxdepth 1 -name 'ssh_host_*' ! -name 'ssh_host_ed25519_key*' -delete")
      ssh("sudo tee /etc/ssh/sshd_config > /dev/null", stdin: DeployUserPatch.sshd_conf)
      ssh("sudo sshd -t && sudo systemctl restart ssh")
      Cmd.ssh("true")
    end

    private

    def ssh(command, stdin: nil)
      Cmd.ssh(command, stdin:, host_key: :known_hosts)
    rescue Net::SSH::HostKeyUnknown
      raise "#{Instance.ip} is not in ~/.ssh/known_hosts, so its current host key cannot be trusted to install the pinned one. Verify the droplet's host key from the DigitalOcean console and add it to ~/.ssh/known_hosts, then deploy again."
    end
  end
end
