# frozen_string_literal: true

require "rails_helper"
require "activeadmin/jobs/adapters/resque"

RSpec.describe ActiveAdmin::Jobs::Adapters::Resque do
  let(:adapter) { ActiveAdmin::Jobs.adapter }

  it "supports workers" do
    expect(adapter.supports?(:workers)).to be true
    expect(adapter.supports?(:recurring_tasks)).to be false
  end

  describe "#workers" do
    it "is empty without workers" do
      expect(adapter.workers).to eq []
    end

    it "lists workers and the jobs they are working on" do
      enqueue_jobs("a")
      working = register_worker("default", "mail.high", working: true)
      register_worker("other")

      workers = adapter.workers.index_by(&:id)
      expect(workers.keys).to contain_exactly(working.to_s, a_string_ending_with(":other"))
      expect(workers[working.to_s]).to have_attributes(
        host: working.hostname, pid: working.pid.to_s, queues: %w[default mail.high], state: :working,
        job_class: "TestJob", job_queue: "default", arguments: ["a"], processed: 0, failed: 0
      )
      expect(workers.values.map(&:state)).to contain_exactly(:working, :idle)
    end
  end

  describe "#stats" do
    it "includes Resque and Redis statistics" do
      fail_jobs("b")
      enqueue_jobs("a")
      register_worker("default")

      expect(adapter.stats).to include(pending: 1, failed: 1, workers: 1, working: 0, queues: 1)
      expect(adapter.stats[:redis_version]).to be_present
    end
  end
end
