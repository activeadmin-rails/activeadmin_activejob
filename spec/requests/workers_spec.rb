# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workers" do
  let(:page) { Capybara.string(response.body) }

  it "lists workers, working first" do
    register_worker("idle")
    enqueue_jobs("a")
    register_worker("default", working: true)
    get "/admin/workers"

    expect(page.all("td.col-state").map { |cell| cell.text.strip }).to eq %w[Working Idle]
    expect(page).to have_css "td.col-job_class", text: "TestJob"
  end

  it "shows a worker and its job" do
    enqueue_jobs("a")
    worker = register_worker("default", "mail.high", working: true)
    get "/admin/workers/#{ActiveAdmin::Jobs::Param.encode(worker.to_s)}"

    expect(response).to have_http_status(:ok)
    expect(page).to have_css ".panel h3", text: "Current Job"
    expect(page).to have_css "pre.job-arguments", text: '"a"'
  end

  it "redirects when the worker is gone" do
    get "/admin/workers/missing"

    expect(response).to redirect_to "/admin/workers"
    expect(flash[:alert]).to eq "The worker is no longer present."
  end
end
