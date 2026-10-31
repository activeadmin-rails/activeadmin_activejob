# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActiveAdmin::Jobs::FailureStats do
  let(:stats) { described_class.new(ActiveAdmin::Jobs::FailedJob.all) }

  def summary(rows)
    rows.map { |row| [row.name, row.total, described_class::PERIODS.map { |hours| row.counts[hours] }] }
  end

  before do
    push_failure("a", job_class: "MailJob", exception: "Net::ReadTimeout", failed_at: 30.minutes.ago)
    push_failure("b", job_class: "MailJob", exception: "KeyError", failed_at: 2.hours.ago)
    push_failure("c", job_class: "SyncJob", exception: "Net::ReadTimeout", failed_at: 2.days.ago)
    push_failure("d", job_class: "SyncJob", exception: "Net::ReadTimeout", failed_at: 10.days.ago)
    push_failure("e", job_class: "AuditJob", exception: "KeyError", failed_at: 5.hours.ago)
  end

  it "counts failures by class and period, most failures first" do
    expect(summary(stats.by_class)).to eq [
      ["MailJob", 2, [1, 2, 2, 2, 2]],
      ["SyncJob", 2, [0, 0, 0, 1, 1]],
      ["AuditJob", 1, [0, 0, 1, 1, 1]]
    ]
  end

  it "counts failures by exception" do
    expect(summary(stats.by_exception)).to eq [
      ["Net::ReadTimeout", 3, [1, 1, 1, 2, 2]],
      ["KeyError", 2, [0, 1, 2, 2, 2]]
    ]
  end

  it "totals" do
    expect(summary([stats.total])).to eq [[nil, 5, [1, 2, 3, 4, 4]]]
    expect(stats).not_to be_truncated
  end

  it "reads at most the scan limit, newest first" do
    ActiveAdmin::Jobs.scan_limit = 2

    expect(stats).to be_truncated
    expect(stats.total.total).to eq 2
    expect(stats.by_class.map(&:name)).to eq %w[AuditJob SyncJob]
  end
end
