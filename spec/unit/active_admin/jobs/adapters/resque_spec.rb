# frozen_string_literal: true

require "rails_helper"
require "activeadmin/jobs/adapters/resque"

# Plain (non-ActiveJob) Resque job.
class PlainResqueJob
  @queue = :plain

  def self.perform(*)
    raise "plain failure"
  end
end

RSpec.describe ActiveAdmin::Jobs::Adapters::Resque do
  let(:adapter) { ActiveAdmin::Jobs.adapter }

  # A new query each time: queries cache their results.
  def failed
    ActiveAdmin::Jobs::FailedJob.all
  end

  def job_with(argument)
    failed.detect { |job| job.arguments.first == argument }
  end

  # Mark an entry retried in place, as resque-web does.
  def mark_retried(argument)
    job = job_with(argument)
    entry = Resque.decode(job.raw).merge("retried_at" => "2026/01/02 03:04:05")
    Resque.redis.lset("failed", job.position, Resque.encode(entry))
  end

  # Overwrite a failed job's ActiveJob data in place.
  def set_executions(argument, counts)
    job = job_with(argument)
    entry = Resque.decode(job.raw)
    entry["payload"]["args"][0].merge!(counts)
    Resque.redis.lset("failed", job.position, Resque.encode(entry))
  end

  def queued_data
    Resque.decode(Resque.redis.lindex("queue:default", 0)).dig("args", 0)
  end

  it "is the adapter for the :resque queue adapter" do
    expect(adapter).to be_a described_class
  end

  describe "listing" do
    before { fail_jobs("a", "b", "c") }

    it "counts and lists newest first" do
      expect(failed.count).to eq 3
      expect(failed.map { |job| job.arguments.first }).to eq %w[c b a]
    end

    it "pages from the newest" do
      expect(failed.offset(1).limit(1).map { |job| job.arguments.first }).to eq %w[b]
      expect(failed.offset(2).limit(5).map { |job| job.arguments.first }).to eq %w[a]
      expect(failed.offset(3).limit(5).to_a).to eq []
    end

    it "paginates for Active Admin" do
      page = failed.page(2).per(2)
      expect(page.map { |job| job.arguments.first }).to eq %w[a]
      expect(page.total_count).to eq 3
      expect(page.current_page).to eq 2
    end

    it "unwraps ActiveJob payloads" do
      job = failed.first
      expect(job).to have_attributes(
        job_class: "TestJob", queue_name: "default", exception_class: "ArgumentError",
        message: "TestJob failed", executions: 0, retried?: false
      )
      expect(job.job_id).to be_present
      expect(job.failed_at).to be_within(1.minute).of(Time.current)
      expect(job.backtrace).to be_present
    end

    it "filters by retried" do
      mark_retried("b")
      expect(failed.where(retried: true).map { |job| job.arguments.first }).to eq %w[b]
      expect(failed.where(retried: false).count).to eq 2
    end
  end

  it "lists plain Resque jobs" do
    Resque.enqueue(PlainResqueJob, 42)
    work_off("plain")

    expect(failed.first).to have_attributes(job_class: "PlainResqueJob", arguments: [42], queue_name: "plain")
  end

  it "masks filtered parameters in arguments" do
    ActiveAdmin::Jobs.filter_parameters = [:password]
    TestJob.perform_later({ "user" => "u", "password" => "secret" }, fail: true)
    work_off

    expect(failed.first.arguments.first).to include("user" => "u", "password" => "[FILTERED]")
    expect(failed.first.entry.to_json).not_to include "secret"
  end

  describe "finding" do
    before { fail_jobs("a", "b", "c") }

    it "finds a job by id" do
      job = job_with("b")
      expect(failed.find(job.id).arguments.first).to eq "b"
    end

    it "finds a job that has moved" do
      job = job_with("c")
      adapter.discard_job(job_with("a"))

      found = failed.find(job.id)
      expect(found.arguments.first).to eq "c"
      expect(found.position).to eq 1
    end

    it "raises when the job is gone" do
      job = job_with("b")
      adapter.discard_job(job)
      expect { failed.find(job.id) }.to raise_error(ActiveAdmin::Jobs::JobNotFound)
      expect(ActiveAdmin::Jobs::FailedJob.find_by(id: job.id)).to be_nil
    end
  end

  describe "#retry_job" do
    before { fail_jobs("a", "b", "c") }

    it "requeues and removes the job" do
      expect(adapter.retry_job(job_with("b"))).to be true

      expect(queued_arguments).to eq ["b"]
      expect(failed_arguments).to eq %w[a c]
    end

    it "marks the job retried instead when configured" do
      ActiveAdmin::Jobs.remove_on_retry = false
      expect(adapter.retry_job(job_with("b"))).to be true

      expect(queued_arguments).to eq ["b"]
      expect(failed.count).to eq 3
      expect(job_with("b").retried_at).to be_within(1.minute).of(Time.current)
    end

    it "retries the right job after the list has changed" do
      stale = job_with("c")
      adapter.discard_job(job_with("a"))

      expect(adapter.retry_job(stale)).to be true
      expect(queued_arguments).to eq ["c"]
      expect(failed_arguments).to eq ["b"]
    end

    it "marks the right job after the list has changed" do
      ActiveAdmin::Jobs.remove_on_retry = false
      stale = job_with("c")
      adapter.discard_job(job_with("a"))

      expect(adapter.retry_job(stale)).to be true
      expect(failed_entries.map { |entry| entry.key?("retried_at") }).to eq [false, true]
    end

    it "requeues a job only once when retried twice" do
      job = job_with("b")
      adapter.retry_job(job)

      expect(adapter.retry_job(job)).to be false
      expect(queued_arguments).to eq ["b"]
    end

    it "does nothing when the job is gone" do
      job = job_with("b")
      adapter.discard_job(job)

      expect(adapter.retry_job(job)).to be false
      expect(queued_arguments).to eq []
    end

    it "resets ActiveJob execution counts" do
      set_executions("a", "executions" => 3, "exception_executions" => { "[ArgumentError]" => 3 })

      adapter.retry_job(job_with("a"))
      expect(queued_data).to include("executions" => 0, "exception_executions" => {}, "job_class" => "TestJob")
      expect(queued_arguments).to eq ["a"]
    end

    it "keeps execution counts when configured" do
      ActiveAdmin::Jobs.reset_executions = false
      set_executions("a", "executions" => 3)

      adapter.retry_job(job_with("a"))
      expect(queued_data["executions"]).to eq 3
    end

    it "can be performed again" do
      adapter.retry_job(job_with("b"))
      work_off

      expect(failed.count).to eq 3
      expect(failed.first.arguments.first).to eq "b"
    end
  end

  it "keeps a failed job's id when marking it retried" do
    ActiveAdmin::Jobs.remove_on_retry = false
    fail_jobs("a")
    job = failed.first

    adapter.retry_job(job)
    expect(failed.first.id).to eq job.id
    expect(failed.find(job.id)).to be_retried
  end

  describe "#discard_job" do
    before { fail_jobs("a", "b") }

    it "removes the job" do
      expect(adapter.discard_job(job_with("a"))).to be true
      expect(failed_arguments).to eq %w[b]
    end

    it "returns false when the job is gone" do
      job = job_with("a")
      adapter.discard_job(job)
      expect(adapter.discard_job(job)).to be false
    end
  end

  describe "bulk actions" do
    before do
      fail_jobs("a", "b", "c")
      mark_retried("b")
    end

    it "retries and removes all jobs not already retried, oldest first" do
      expect(failed.retry_all).to eq 2
      expect(queued_arguments).to eq %w[a c]
      expect(failed_arguments).to eq %w[b]
    end

    it "retries all jobs, including those already retried, when marking retried" do
      ActiveAdmin::Jobs.remove_on_retry = false
      expect(failed.retry_all).to eq 3
      expect(queued_arguments).to eq %w[a b c]
      expect(failed.where(retried: false).count).to eq 0
    end

    it "clears retried jobs" do
      expect(failed.where(retried: true).discard_all).to eq 1
      expect(failed_arguments).to eq %w[a c]
    end

    it "clears all jobs" do
      expect(failed.discard_all).to eq 3
      expect(failed.count).to eq 0
    end
  end

  it "rejects unsupported failure backends" do
    allow(Resque::Failure).to receive(:backend).and_return(Class.new {
      def self.name
        "Resque::Failure::RedisMultiQueue"
      end
    })
    expect { failed.to_a }.to raise_error(ActiveAdmin::Jobs::Adapters::UnsupportedBackend, /RedisMultiQueue/)
  end
end
