# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Failed Jobs" do
  let(:page) { Capybara.string(response.body) }

  def failed
    ActiveAdmin::Jobs::FailedJob.all
  end

  def job_with(argument)
    failed.detect { |job| job.arguments.first == argument }
  end

  describe "index" do
    it "lists failed jobs newest first" do
      fail_jobs("a", "b")
      get "/admin/failed_jobs"

      expect(response).to have_http_status(:ok)
      expect(page).to have_css "td.col-job_class", text: "TestJob", count: 2
      expect(page).to have_css "td.col-exception_class", text: "ArgumentError"
      ids = page.all("tbody tr").map { |row| row["id"].delete_prefix("active_admin_jobs_failed_job_") }
      expect(ids).to eq [job_with("b").id, job_with("a").id]
    end

    it "offers collection actions" do
      fail_jobs("a")
      get "/admin/failed_jobs"

      expect(page).to have_link "Retry All"
      expect(page).to have_link "Clear All"
      expect(page).to have_no_link "Clear Retried"
      expect(page).to have_no_css "th.col-retried_at"
    end

    it "shows retried state when jobs are marked retried" do
      ActiveAdmin::Jobs.remove_on_retry = false
      fail_jobs("a", "b")
      ActiveAdmin::Jobs.adapter.retry_job(job_with("a"))
      ActiveAdmin::Jobs.remove_on_retry = true
      get "/admin/failed_jobs"

      expect(page).to have_link "Clear Retried"
      expect(page).to have_css "td.col-retried_at", text: /\d/, count: 1
    end

    it "paginates" do
      fail_jobs(*("a".."c").to_a)
      get "/admin/failed_jobs", params: { per_page: 2, page: 2 }

      expect(page).to have_css "tbody tr", count: 1
      expect(page).to have_css ".pagination_information", text: /3.-.3 of 3/
    end

    it "renders when there are no failed jobs" do
      get "/admin/failed_jobs"

      expect(response).to have_http_status(:ok)
      expect(page).to have_css ".blank_slate"
      expect(page).to have_no_link "Retry All"
    end
  end

  describe "show" do
    it "shows the job and its failure" do
      fail_jobs("a")
      get "/admin/failed_jobs/#{job_with("a").id}"

      expect(response).to have_http_status(:ok)
      expect(page).to have_css "pre.job-arguments", text: '"a"'
      expect(page).to have_css "pre.job-backtrace", text: "test_job.rb"
      expect(page).to have_css ".panel h3", text: "ArgumentError"
      expect(page).to have_link "Retry"
    end

    it "redirects when the job is gone" do
      fail_jobs("a")
      id = job_with("a").id
      Resque::Failure.clear
      get "/admin/failed_jobs/#{id}"

      expect(response).to redirect_to "/admin/failed_jobs"
      expect(flash[:alert]).to eq "The job is no longer present."
    end
  end

  describe "member actions" do
    before { fail_jobs("a", "b") }

    it "retries a job" do
      post "/admin/failed_jobs/#{job_with("a").id}/retry"

      expect(response).to redirect_to "/admin/failed_jobs"
      expect(flash[:notice]).to eq "1 job retried."
      expect(queued_arguments).to eq ["a"]
      expect(failed_arguments).to eq ["b"]
    end

    it "removes a job" do
      delete "/admin/failed_jobs/#{job_with("a").id}"

      expect(response).to redirect_to "/admin/failed_jobs"
      expect(flash[:notice]).to eq "1 job removed."
      expect(failed_arguments).to eq ["b"]
    end
  end

  describe "collection actions" do
    before do
      ActiveAdmin::Jobs.remove_on_retry = false
      fail_jobs("a", "b", "c")
      ActiveAdmin::Jobs.adapter.retry_job(job_with("b"))
    end

    it "retries all jobs" do
      post "/admin/failed_jobs/retry_all"

      expect(flash[:notice]).to eq "3 jobs retried."
      expect(queued_arguments).to eq %w[b a b c]
    end

    it "clears retried jobs" do
      delete "/admin/failed_jobs/clear_retried"

      expect(flash[:notice]).to eq "1 job removed."
      expect(failed_arguments).to eq %w[a c]
    end

    it "clears all jobs" do
      delete "/admin/failed_jobs/clear_all"

      expect(flash[:notice]).to eq "3 jobs removed."
      expect(failed.count).to eq 0
    end
  end

  describe "batch actions" do
    before { fail_jobs("a", "b", "c") }

    let(:selection) { [job_with("a").id, job_with("c").id] }

    it "offers retry and remove" do
      get "/admin/failed_jobs"

      expect(page).to have_css "a.batch_action[data-action='retry']"
      expect(page).to have_css "a.batch_action[data-action='discard']"
      expect(page).to have_no_css "a.batch_action[data-action='destroy']"
    end

    it "retries the selected jobs" do
      post "/admin/failed_jobs/batch_action", params: { batch_action: "retry", collection_selection: selection }

      expect(flash[:notice]).to eq "2 jobs retried."
      expect(queued_arguments).to eq %w[c a]
    end

    it "removes the selected jobs" do
      post "/admin/failed_jobs/batch_action", params: { batch_action: "discard", collection_selection: selection }

      expect(flash[:notice]).to eq "2 jobs removed."
      expect(failed_arguments).to eq %w[b]
    end
  end

  context "when not authorized to retry" do
    let(:no_retry) do
      Class.new(ActiveAdmin::AuthorizationAdapter) do
        def authorized?(action, _subject = nil)
          action != :retry
        end
      end
    end

    around do |example|
      namespace = ActiveAdmin.application.namespace(:admin)
      original = namespace.authorization_adapter
      namespace.authorization_adapter = no_retry
      example.run
    ensure
      namespace.authorization_adapter = original
    end

    before { fail_jobs("a") }

    it "hides retry actions" do
      get "/admin/failed_jobs"

      expect(page).to have_no_link "Retry All"
      expect(page).to have_no_css "a.batch_action[data-action='retry']"
      expect(page).to have_link "Clear All"
    end

    it "refuses to retry" do
      post "/admin/failed_jobs/#{job_with("a").id}/retry"

      expect(queued_arguments).to eq []
      expect(flash[:error]).to be_present
    end
  end
end
