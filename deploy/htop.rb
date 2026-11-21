require_relative "lib/require"

cmd = [
  "ssh",
  *Cmd.ssh_options,
  "-t",
  "#{Constants.deploy_user}@#{Instance.ip}",
  'htop',
]
puts cmd.join(" ")
system(*cmd)
