# frozen_string_literal: true

# Helpers to put jobs into Resque the way a real app and worker would.
module ResqueHelpers
  # Reserve and perform the next job on +queue+ in-process, recording any
  # failure through the configured Resque::Failure backend.
  def work_off(queue = "default")
    job = Resque::Job.reserve(queue) or return
    job.perform
  rescue StandardError => e
    job.fail(e)
  end

  # Record a failed TestJob for each of +args+, oldest first.
  def fail_jobs(*args)
    args.each do |arg|
      TestJob.perform_later(arg, fail: true)
      work_off
    end
  end

  # Enqueue a TestJob on +queue+ for each of +args+.
  def enqueue_jobs(*args, queue: "default")
    args.each { |arg| TestJob.set(queue:).perform_later(arg) }
  end

  # Register a worker, optionally working on the next job from its first queue.
  def register_worker(*queues, working: false)
    worker = Resque::Worker.new(*queues)
    worker.register_worker
    worker.working_on(Resque::Job.reserve(queues.first)) if working
    worker
  end

  def failed_entries
    Resque.redis.lrange("failed", 0, -1).map { |json| Resque.decode(json) }
  end

  def failed_arguments
    failed_entries.map { |entry| entry.dig("payload", "args", 0, "arguments", 0) }
  end

  def queued_arguments(queue = "default")
    Resque.redis.lrange("queue:#{queue}", 0, -1).map { |json| Resque.decode(json).dig("args", 0, "arguments", 0) }
  end
end

RSpec.configure do |config|
  config.include ResqueHelpers
end
