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
end

RSpec.configure do |config|
  config.include ResqueHelpers
end
