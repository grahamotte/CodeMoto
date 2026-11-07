module Apps
  class BrewUpgradePatch < BasePatch
    TAP = "grahamotte/tap"

    class << self
      def needed?
        CaskPatch.needed? && Apps.brew_installed? && installed?
      end

      def apply
        running = Cmd.local(Shellwords.join([ "osascript", "-e", "application #{name.to_json} is running" ])).strip == "true"
        brew("update")
        brew("upgrade", "--cask", cask)
        return unless running

        Cmd.local(Shellwords.join([ "osascript", "-e", "quit app #{name.to_json}" ]))
        Cmd.local(Shellwords.join([ "open", "-a", name ]))
      end

      private

      def installed?
        JSON.parse(brew("info", "--cask", "--json=v2", "--installed"))
          .fetch("casks", [])
          .any? { |item| item["full_token"] == cask }
      end

      def brew(*arguments)
        Bundler.with_unbundled_env { Cmd.local(Shellwords.join([ "brew", *arguments ])) }
      end

      def cask = "#{TAP}/#{CaskPatch.token}"

      def name = Apps.config.fetch(:name)
    end
  end
end
