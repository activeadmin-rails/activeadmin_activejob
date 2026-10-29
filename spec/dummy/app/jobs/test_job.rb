# frozen_string_literal: true

# Raises when asked to, so specs can produce failed jobs.
class TestJob < ApplicationJob
  queue_as :default

  def perform(fail: false)
    raise ArgumentError, "TestJob failed" if fail
  end
end
