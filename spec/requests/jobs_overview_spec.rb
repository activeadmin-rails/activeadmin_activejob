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

  it "offers to clear each queue" do
    enqueue_jobs("c", queue: "mail.high")
    get "/admin/jobs"

    link = page.find_link("Clear Queue", href: "/admin/queued_jobs/clear?queue=mail.high")
    expect(link["data-method"]).to eq "delete"
    expect(link["data-confirm"]).to eq "Remove queue mail.high and its 1 job?"
  end

  it "offers to hide empty queues" do
    Resque.watch_queue("empty")
    get "/admin/jobs"

    expect(page).to have_link "empty"
    expect(page).to have_link "Hide Empty Queues", href: "/admin/jobs?hide_empty=1"
  end

  it "hides empty queues, keeping live poll" do
    enqueue_jobs("c", queue: "mail.high")
    Resque.watch_queue("empty")
    get "/admin/jobs", params: { hide_empty: 1, poll: 1 }

    expect(page).to have_link "mail.high"
    expect(page).to have_no_link "empty", exact: true
    expect(page).to have_link "Show Empty Queues", href: "/admin/jobs?poll=1"
    expect(page).to have_link "Stop Live Poll", href: "/admin/jobs?hide_empty=1"
    expect(page).to have_link "Clear Queue", href: "/admin/queued_jobs/clear?hide_empty=1&poll=1&queue=mail.high"
  end

  it "puts working workers above statistics" do
    get "/admin/jobs"

    titles = page.all(".column").map { |column| column.all(".panel h3").map { |h3| h3.text.squish } }
    expect(titles).to match [[a_string_starting_with("Queues")], ["0 Workers Working", "Resque & Redis"]]
  end

  it "counts scheduled jobs in the statistics" do
    schedule_jobs("s")
    get "/admin/jobs"

    expect(page).to have_css "table.job-stats tr", text: /Scheduled\s+1/
  end
end
