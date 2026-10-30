# frozen_string_literal: true

require "rails_helper"
require "activeadmin/jobs/adapters/resque"

RSpec.describe ActiveAdmin::Jobs::Adapters::Resque do
  let(:adapter) { ActiveAdmin::Jobs.adapter }

  def queued(queue = "default")
    ActiveAdmin::Jobs::QueuedJob.all.where(queue:)
  end

  def job_with(argument, queue = "default")
    queued(queue).detect { |job| job.arguments.first == argument }
  end

  describe "#queues" do
    it "lists queues with sizes, sorted by name" do
      enqueue_jobs("a", "b")
      enqueue_jobs("c", queue: "mail.high")

      expect(adapter.queues.map { |queue| [queue.name, queue.size] }).to eq [["default", 2], ["mail.high", 1]]
    end

    it "removes a queue with its jobs" do
      enqueue_jobs("a", "b")

      expect(adapter.clear_queue("default")).to eq 2
      expect(adapter.queues).to eq []
      expect(queued_arguments).to eq []
    end
  end

  describe "queued jobs" do
    before { enqueue_jobs("a", "b", "c") }

    it "lists jobs in the order they will run" do
      expect(queued.count).to eq 3
      expect(queued.map { |job| job.arguments.first }).to eq %w[a b c]
      expect(queued.offset(1).limit(1).map { |job| job.arguments.first }).to eq %w[b]
    end

    it "unwraps ActiveJob payloads" do
      expect(queued.first).to have_attributes(job_class: "TestJob", queue_name: "default", position: 0)
      expect(queued.first.enqueued_at).to be_within(1.minute).of(Time.current)
    end

    it "needs a queue" do
      expect(queued(nil).count).to eq 0
      expect(queued(nil).to_a).to eq []
    end

    it "finds a job, including after it has moved" do
      job = job_with("c")
      expect(queued.find(job.id).arguments.first).to eq "c"

      Resque.redis.lpop("queue:default")
      expect(queued.find(job.id).position).to eq 1
    end

    it "finds jobs in queues with dots in their names" do
      enqueue_jobs("d", queue: "mail.high")
      job = job_with("d", "mail.high")

      expect(job.to_param).not_to include "."
      expect(queued("mail.high").find(ActiveAdmin::Jobs::Param.decode(job.to_param)).arguments.first).to eq "d"
    end

    it "removes a job" do
      job = job_with("b")

      expect(adapter.discard_job(job)).to be true
      expect(adapter.discard_job(job)).to be false
      expect(queued_arguments).to eq %w[a c]
    end
  end
end
