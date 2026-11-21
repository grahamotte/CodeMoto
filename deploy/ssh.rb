require_relative "lib/require"

system("ssh", *Cmd.ssh_options, "-t", "#{Constants.deploy_user}@#{Instance.ip}")
