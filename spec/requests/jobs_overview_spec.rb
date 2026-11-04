# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Jobs overview" do
  let(:page) { Capybara.string(response.body) }

  it "shows queues, failures, working workers and statistics" do
    fail_jobs("f")
    enqueue_jobs("a", "b")
    enqueue_jobs("c", queue: "mail.high")
    register_worker("mail.high", working: true)
    get "/admin/jobs"

    expect(response).to have_http_status(:ok)
    expect(page).to have_link "mail.high", href: "/admin/queued_jobs?queue=mail.high"
    expect(page).to have_no_css "table.job-stats tr", text: /Failed/
    expect(page).to have_css ".panel h3", text: "1 Worker Working"
    expect(page).to have_css "table.job-stats td", text: "Redis version"
  end

  it "puts working workers above statistics" do
    get "/admin/jobs"

    titles = page.all(".column").map { |column| column.all(".panel h3").map(&:text) }
    expect(titles).to eq [["Queues"], ["0 Workers Working", "Resque & Redis"]]
  end

  it "counts scheduled jobs in the statistics" do
    schedule_jobs("s")
    get "/admin/jobs"

    expect(page).to have_css "table.job-stats tr", text: /Scheduled\s+1/
  end
end
