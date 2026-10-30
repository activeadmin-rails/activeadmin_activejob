# frozen_string_literal: true

require "rails_helper"
require "activeadmin/jobs/adapters/resque"

RSpec.describe ActiveAdmin::Jobs::Adapters::Resque do
  let(:adapter) { ActiveAdmin::Jobs.adapter }
  let(:at) { 1.hour.from_now.change(usec: 0) }

  def scheduled
    ActiveAdmin::Jobs::ScheduledJob.all
  end

  def job_with(argument)
    scheduled.detect { |job| job.arguments.first == argument }
  end

  it "supports scheduled jobs with resque-scheduler" do
    expect(adapter.supports?(:scheduled_jobs)).to be true
  end

  describe "listing" do
    before do
      schedule_jobs("c", at: at + 60)
      schedule_jobs("a", at:)
      TestJob.set(wait_until: at, queue: "mail.high").perform_later("b")
    end

    it "counts and lists soonest first" do
      expect(scheduled.count).to eq 3
      expect(scheduled.map { |job| job.arguments.first }).to eq %w[a b c]
    end

    it "pages across timestamps" do
      expect(scheduled.offset(1).limit(2).map { |job| job.arguments.first }).to eq %w[b c]
      expect(scheduled.offset(3).limit(2).to_a).to eq []
      expect(scheduled.page(2).per(2).map { |job| job.arguments.first }).to eq %w[c]
    end

    it "unwraps ActiveJob payloads" do
      expect(job_with("b")).to have_attributes(job_class: "TestJob", queue_name: "mail.high", scheduled_at: at)
    end

    it "finds a job, including after it has moved" do
      job = job_with("b")
      expect(scheduled.find(job.id).arguments.first).to eq "b"

      adapter.discard_job(job_with("a"))
      expect(scheduled.find(job.id).position).to eq 0
    end
  end

  it "lists plain Resque jobs" do
    Resque.enqueue_at_with_queue("plain", at, "PlainJob", 1)

    expect(scheduled.first).to have_attributes(job_class: "PlainJob", arguments: [1], queue_name: "plain")
  end

  describe "#enqueue_now" do
    before { schedule_jobs("a", "b") }

    it "moves the job to its queue" do
      expect(adapter.enqueue_now(job_with("a"))).to be true

      expect(queued_arguments).to eq ["a"]
      expect(scheduled_arguments).to eq ["b"]
    end

    it "enqueues a job only once" do
      job = job_with("a")
      adapter.enqueue_now(job)

      expect(adapter.enqueue_now(job)).to be false
      expect(queued_arguments).to eq ["a"]
    end

    it "enqueues a job that can be performed" do
      adapter.enqueue_now(job_with("a"))
      expect { work_off }.not_to raise_error
      expect(Resque::Failure.count).to eq 0
    end
  end

  describe "#discard_job" do
    it "cancels an ActiveJob job and cleans up resque-scheduler's keys" do
      schedule_jobs("a", "b", at:)
      job = job_with("a")

      expect(adapter.discard_job(job)).to be true
      expect(scheduled_arguments).to eq ["b"]
      expect(Resque.redis.exists?("timestamps:#{job.raw}")).to be false
      expect(Resque.delayed_queue_schedule_size).to eq 1
      expect(Resque.redis.exists?("delayed:#{at.to_i}")).to be false
    end

    it "returns false when the job is gone" do
      schedule_jobs("a")
      job = job_with("a")
      adapter.discard_job(job)

      expect(adapter.discard_job(job)).to be false
    end
  end

  it "clears all scheduled jobs" do
    schedule_jobs("a", "b")

    expect(scheduled.discard_all).to eq 2
    expect(scheduled.count).to eq 0
    expect(Resque.delayed_queue_schedule_size).to eq 0
  end

  it "counts scheduled jobs in stats" do
    schedule_jobs("a", "b")
    expect(adapter.stats[:scheduled]).to eq 2
  end
end
