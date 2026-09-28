require "open3"

class LinearSyncAll
  TASK = "manager:linear_sync"

  class << self
    def call
      ran = []
      skipped = []

      entries.each do |path|
        case classify(path)
        when :run
          ran << path
        when :skip
          skipped << path
        end
      end

      skipped.each { |path| warn_missing(path) }
      ran.each { |path| sync(path) }
      summarize(ran, skipped)
    end

    def directories
      entries.filter_map { |path| path if classify(path) == :run }
    end

    private

    def entries
      Dir.children(parent).sort.map { |name| File.join(parent, name) }
    end

    def parent
      File.expand_path("..", Worktree.root)
    end

    def classify(path)
      return :ignore unless git_repo?(path)
      return :ignore unless File.file?(toml(path))

      contents = File.read(toml(path))
      return :run if contents.include?(task_header)
      return :skip if contents.include?("manager:")

      :ignore
    end

    def git_repo?(path)
      File.directory?(path) && File.directory?(File.join(path, ".git"))
    end

    def toml(path)
      File.join(path, "mise.toml")
    end

    def task_header
      "[tasks.\"#{TASK}\"]"
    end

    def warn_missing(path)
      $stdout.puts("skipping #{File.basename(path)}: no #{TASK} task (merge latest Code Moto)")
    end

    def sync(directory)
      $stdout.puts("==> #{File.basename(directory)}")
      stdout, stderr, status = Open3.capture3("mise", TASK, chdir: directory)
      $stdout.print(stdout)
      $stdout.puts if stdout.present? && !stdout.end_with?("\n")
      $stderr.print(stderr) if stderr.present?
      return if status.success?

      message = stderr.strip
      message = stdout.strip if message.blank?
      raise "mise #{TASK} failed in #{directory}: #{message}"
    end

    def summarize(ran, skipped)
      $stdout.puts("ran: #{names(ran)}")
      $stdout.puts("skipped: #{names(skipped)}")
    end

    def names(paths)
      paths.map { |path| File.basename(path) }.join(", ")
    end
  end
end
