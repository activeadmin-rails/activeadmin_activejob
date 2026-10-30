# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Scheduled Jobs" do
  let(:page) { Capybara.string(response.body) }

  def job_with(argument)
    ActiveAdmin::Jobs::ScheduledJob.all.detect { |job| job.arguments.first == argument }
  end

  before { schedule_jobs("a", "b", "c") }

  it "lists scheduled jobs soonest first" do
    get "/admin/scheduled_jobs"

    expect(page.all("td.col-arguments").map(&:text)).to eq %w[["a"] ["b"] ["c"]]
    expect(page).to have_link "Clear All"
    expect(page).to have_css "a.batch_action[data-action='enqueue_now']"
    expect(page).to have_css "a.batch_action[data-action='discard']"
  end

  it "shows a job" do
    get "/admin/scheduled_jobs/#{job_with("a").to_param}"

    expect(response).to have_http_status(:ok)
    expect(page).to have_css "pre.job-arguments", text: '"a"'
    expect(page).to have_link "Enqueue Now"
  end

  it "enqueues a job now" do
    post "/admin/scheduled_jobs/#{job_with("b").to_param}/enqueue_now"

    expect(response).to redirect_to "/admin/scheduled_jobs"
    expect(flash[:notice]).to eq "1 job enqueued."
    expect(queued_arguments).to eq ["b"]
    expect(scheduled_arguments).to eq %w[a c]
  end

  it "cancels a job" do
    delete "/admin/scheduled_jobs/#{job_with("b").to_param}"

    expect(flash[:notice]).to eq "1 job removed."
    expect(scheduled_arguments).to eq %w[a c]
  end

  it "enqueues selected jobs" do
    ids = [job_with("a").id, job_with("c").id]
    post "/admin/scheduled_jobs/batch_action", params: { batch_action: "enqueue_now", collection_selection: ids }

    expect(flash[:notice]).to eq "2 jobs enqueued."
    expect(queued_arguments).to contain_exactly("a", "c")
  end

  it "clears all scheduled jobs" do
    delete "/admin/scheduled_jobs/clear_all"

    expect(flash[:notice]).to eq "3 jobs removed."
    expect(scheduled_arguments).to eq []
  end
end
