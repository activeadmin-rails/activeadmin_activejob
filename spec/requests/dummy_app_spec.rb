# frozen_string_literal: true

require "rails_helper"

# Smoke test of the test harness: Active Admin renders and ActiveJob runs on Resque.
RSpec.describe "dummy app" do
  it "renders the Active Admin dashboard" do
    get "/admin"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Welcome to the ActiveAdmin ActiveJob test app.")
  end

  it "enqueues ActiveJob jobs into Resque" do
    TestJob.perform_later

    payload = Resque.peek("default")
    expect(payload["class"]).to eq "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"
    expect(payload["args"].first["job_class"]).to eq "TestJob"
  end

  it "records failed jobs" do
    TestJob.perform_later(fail: true)
    work_off

    failure = Resque::Failure.all
    expect(failure["exception"]).to eq "ArgumentError"
    expect(failure["payload"]["args"].first["job_class"]).to eq "TestJob"
  end
end
