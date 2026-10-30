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
    expect(page).to have_link "1 failed job", href: "/admin/failed_jobs"
    expect(page).to have_css ".panel h3", text: "1 Worker Working"
    expect(page).to have_css "table.job-stats td", text: "Redis version"
  end
end
