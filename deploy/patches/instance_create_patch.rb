class InstanceCreatePatch < BasePatch
  class << self
    def needed?
      !Instance.running?
    end

    def apply
      Cache.clear
      Instance.clear
      Instance.create

      loop do
        break if instance_ready?
        sleep 4
      end
    end

    private

    def instance_ready?
      Instance.clear
      return false unless Instance.running?

      begin
        res = Cmd.ssh("echo !ass!tits!", user: "root")
        res.include?("!ass!tits!")
      rescue StandardError => e
        puts e.message
        false
      end
    end
  end
end
