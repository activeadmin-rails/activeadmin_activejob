# frozen_string_literal: true

require "rails_helper"
require "activeadmin/jobs/adapters/resque"

RSpec.describe ActiveAdmin::Jobs::Adapters::Resque do
  def failed(**filters)
    ActiveAdmin::Jobs::FailedJob.all.where(**filters)
  end

  def arguments(query)
    query.map { |job| job.arguments.first }
  end

  before do
    push_failure("a", job_class: "MailJob", exception: "Net::ReadTimeout", failed_at: 30.hours.ago, queue: "mail")
    push_failure("b", job_class: "SyncJob", exception: "Net::ReadTimeout", failed_at: 2.hours.ago)
    push_failure("c", job_class: "MailJob", exception: "KeyError", failed_at: 10.minutes.ago, queue: "mail")
  end

  it "filters by job class, exception and queue" do
    expect(arguments(failed(job_class: "MailJob"))).to eq %w[c a]
    expect(arguments(failed(exception_class: "Net::ReadTimeout"))).to eq %w[b a]
    expect(arguments(failed(queue_name: "default"))).to eq %w[b]
    expect(failed(job_class: "MailJob", exception_class: "KeyError").count).to eq 1
  end

  it "filters by failure time" do
    expect(arguments(failed(failed_after: 3.hours.ago))).to eq %w[c b]
    expect(arguments(failed(failed_before: 1.hour.ago))).to eq %w[b a]
    expect(arguments(failed(failed_after: 1.day.ago, failed_before: 1.hour.ago))).to eq %w[b]
  end

  it "filters by a pattern over the entry" do
    expect(arguments(failed(pattern: /KeyError|"a"/))).to eq %w[c a]
  end

  it "does not match masked parameters" do
    ActiveAdmin::Jobs.filter_parameters = [:password]
    push_failure({ "password" => "secret" })

    expect(failed(pattern: /secret/).count).to eq 0
    expect(failed(pattern: /FILTERED/).count).to eq 1
  end

  it "pages filtered results" do
    expect(arguments(failed(job_class: "MailJob").offset(1).limit(1))).to eq %w[a]
  end

  it "retries and clears filtered jobs only" do
    expect(failed(job_class: "MailJob").retry_all).to eq 2
    expect(queued_arguments("mail")).to eq %w[a c]
    expect(failed_arguments).to eq %w[b]

    expect(failed(exception_class: "Net::ReadTimeout").discard_all).to eq 1
    expect(failed.count).to eq 0
  end

  it "rejects unknown filters" do
    expect { failed(colour: "red").to_a }.to raise_error(ArgumentError, /colour/)
  end

  describe "#truncated?" do
    it "is true when a filtered scan stops at the scan limit" do
      ActiveAdmin::Jobs.scan_limit = 2

      expect(failed(job_class: "MailJob")).to be_truncated
      expect(arguments(failed(job_class: "MailJob"))).to eq %w[c]
      expect(failed).not_to be_truncated
      expect(failed.count).to eq 3
    end

    it "is false within the scan limit" do
      expect(failed(job_class: "MailJob")).not_to be_truncated
    end
  end
end
