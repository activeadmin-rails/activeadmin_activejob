# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Queued Jobs" do
  let(:page) { Capybara.string(response.body) }

  def queued(queue = "default")
    ActiveAdmin::Jobs::QueuedJob.all.where(queue:)
  end

  def job_with(argument, queue = "default")
    queued(queue).detect { |job| job.arguments.first == argument }
  end

  describe "index" do
    before do
      enqueue_jobs("a", "b")
      enqueue_jobs("c", queue: "mail.high")
    end

    it "lists the first queue's jobs by default" do
      get "/admin/queued_jobs"

      expect(page).to have_css "#page_title", text: "Queued Jobs: default"
      expect(page).to have_css "td.col-arguments", text: '"a"'
      expect(page).to have_css "td.col-arguments", count: 2
    end

    it "lists the selected queue's jobs, with links to each queue" do
      get "/admin/queued_jobs", params: { queue: "mail.high" }

      expect(page).to have_css "#page_title", text: "Queued Jobs: mail.high"
      expect(page).to have_css "td.col-arguments", text: '"c"', count: 1
      expect(page).to have_css "#queues_sidebar_section li.current", text: "mail.high (1)"
      expect(page).to have_link "default (2)", href: "/admin/queued_jobs?queue=default"
    end

    it "offers removal as a batch action" do
      get "/admin/queued_jobs"

      expect(page).to have_css "a.batch_action[data-action='discard']"
      expect(page).to have_no_css "a.batch_action[data-action='destroy']"
    end
  end

  it "renders without queues" do
    get "/admin/queued_jobs"

    expect(response).to have_http_status(:ok)
    expect(page).to have_css ".blank_slate"
  end

  it "shows a job in a queue with dots in its name" do
    enqueue_jobs("c", queue: "mail.high")
    get "/admin/queued_jobs/#{job_with("c", "mail.high").to_param}"

    expect(response).to have_http_status(:ok)
    expect(page).to have_css "pre.job-arguments", text: '"c"'
  end

  it "removes a job" do
    enqueue_jobs("a", "b", queue: "mail.high")
    delete "/admin/queued_jobs/#{job_with("a", "mail.high").to_param}"

    expect(response).to redirect_to "/admin/queued_jobs?queue=mail.high"
    expect(flash[:notice]).to eq "1 job removed."
    expect(queued_arguments("mail.high")).to eq %w[b]
  end

  it "removes selected jobs, reporting those already gone" do
    enqueue_jobs("a", "b", "c", queue: "mail.high")
    ids = [job_with("a", "mail.high"), job_with("c", "mail.high")].map(&:id)
    Resque.redis.lpop("queue:mail.high")
    post "/admin/queued_jobs/batch_action", params: { batch_action: "discard", collection_selection: ids }

    expect(response).to redirect_to "/admin/queued_jobs?queue=mail.high"
    expect(flash[:notice]).to eq "1 job removed."
    expect(flash[:alert]).to eq "1 of the selected jobs is no longer present."
    expect(queued_arguments("mail.high")).to eq %w[b]
  end
end
