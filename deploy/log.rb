require_relative "lib/require"

cmd = [
  "ssh",
  *Cmd.ssh_options,
  "-t",
  "#{Constants.deploy_user}@#{Instance.ip}",
  "sudo journalctl -f -u api",
]
puts cmd.join(" ")
system(*cmd)
