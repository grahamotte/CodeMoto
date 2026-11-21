class Cmd
  class SshError < RuntimeError
    attr_reader :output

    def initialize(message, output:)
      @output = output
      super(message)
    end
  end

  class << self
    def local(command, *opts)
      command = command.split("?").zip(opts.map { |x| Shellwords.escape(x) }).flatten.join if opts.present?
      command = command.gsub("\\*", "*")

      puts "CMD #{command}".green

      res = `#{command}`
      puts res
      raise "Command failed: #{command}" unless command_succeeded?

      res
    end

    def ssh(command, *opts, user: Constants.deploy_user, quiet: false, stdin: nil, out: $stdout, err: $stdout, host_key: :pinned)
      command = command.split("?").zip(opts.map { |x| Shellwords.escape(x) }).flatten.join if opts.present?
      command = command.gsub("\\*", "*")

      puts "SSH #{command}".green unless quiet

      text = +""
      code = 0

      Net::SSH.start(Instance.ip, user, **ssh_connection_options(host_key)) do |s|
        s.open_channel do |channel|
          channel.exec(command) do
            if stdin.present?
              channel.send_data(stdin)
              channel.eof!
            end
            channel.on_data { |_, x| out.print(x) unless quiet; text += x }
            channel.on_extended_data { |_, _, x| err.print(x) unless quiet; text += x }
            channel.on_request("exit-status") { |_, x| code = x.read_long }
          end
        end
        s.loop
      end

      text = text.force_encoding(Encoding::UTF_8)
      raise SshError.new("SSH command failed: #{command}", output: text) if code != 0

      text
    end

    def ssh_write(path, content, user: Constants.deploy_user, sudo: false)
      digest = Digest::SHA256.hexdigest(content) if content.present?
      if Cache.unchanged?(path, digest)
        puts "SSH skip write #{path} because it hasn't changed"
        return
      end

      tee = sudo && user != "root" ? "sudo tee" : "tee"
      ssh("#{tee} ? > /dev/null", path, user:, stdin: content)
      Cache.set(path, digest)
    end

    def ssh_options
      [
        "-i", Constants.ssh_key_path,
        "-o", "IdentitiesOnly=yes",
        "-o", "StrictHostKeyChecking=yes",
        "-o", "UserKnownHostsFile=#{Constants.ssh_known_hosts_path}",
        "-o", "GlobalKnownHostsFile=/dev/null",
        "-o", "HostKeyAlias=#{Constants.domain}",
      ]
    end

    def ssh_command = Shellwords.join([ "ssh", *ssh_options ])

    private

    def ssh_connection_options(host_key)
      options = { keys: [ Constants.ssh_key_path ], keys_only: true, verify_host_key: :always }
      return options if host_key == :known_hosts

      options.merge(
        host_key_alias: Constants.domain,
        user_known_hosts_file: [ Constants.ssh_known_hosts_path ],
        global_known_hosts_file: [],
      )
    end

    def command_succeeded?
      Process.last_status.blank? || Process.last_status.success?
    end
  end
end
