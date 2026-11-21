require_relative "lib/require"

cmd = [
  "ssh",
  *Cmd.ssh_options,
  "-t",
  "#{Constants.deploy_user}@#{Instance.ip}",
  Instance.app_command("cd #{Constants.remote_root}/backend && set -a && source ../.env && mise exec -- rails console"),
]
puts cmd.join(" ")
system(*cmd)
