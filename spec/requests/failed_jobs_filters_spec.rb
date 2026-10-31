# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Failed Jobs filters and stats" do
  let(:page) { Capybara.string(response.body) }

  before do
    push_failure("a", job_class: "MailJob", exception: "Net::ReadTimeout", failed_at: 30.hours.ago)
    push_failure("b", job_class: "SyncJob", exception: "KeyError", failed_at: 2.hours.ago)
    push_failure("c", job_class: "MailJob", exception: "KeyError", failed_at: 10.minutes.ago)
  end

  # Arguments of the listed jobs, from the latest response.
  def listed_arguments
    Capybara.string(response.body).all("tbody tr").map do |row|
      ActiveAdmin::Jobs::FailedJob.find(row["id"].delete_prefix("active_admin_jobs_failed_job_")).arguments.first
    end
  end

  describe "index" do
    it "shows the filters sidebar" do
      get "/admin/failed_jobs"

      expect(page).to have_css "#filters_sidebar_section form[method=get]"
      expect(page).to have_field "filter[job_class]"
      expect(page).to have_select "filter[newer_than]", with_options: ["1 hour", "7 days"]
      expect(page).to have_field "filter[pattern]"
    end

    it "filters by class, exception and age" do
      get "/admin/failed_jobs", params: { filter: { job_class: "MailJob" } }
      expect(listed_arguments).to eq %w[c a]
      expect(page).to have_field "filter[job_class]", with: "MailJob"

      get "/admin/failed_jobs", params: { filter: { exception_class: "KeyError", newer_than: "1" } }
      expect(listed_arguments).to eq %w[c]

      get "/admin/failed_jobs", params: { filter: { older_than: "24", job_class: "" } }
      expect(listed_arguments).to eq %w[a]
    end

    it "filters by pattern" do
      get "/admin/failed_jobs", params: { filter: { pattern: "Net::Read" } }
      expect(listed_arguments).to eq %w[a]
    end

    it "rejects an invalid pattern" do
      get "/admin/failed_jobs", params: { filter: { pattern: "(" } }

      expect(response).to redirect_to("/admin/failed_jobs")
      expect(flash[:alert]).to start_with "Invalid pattern"
    end

    it "keeps filters on collection actions" do
      get "/admin/failed_jobs", params: { filter: { job_class: "MailJob" } }

      expect(page).to have_link "Retry All", href: "/admin/failed_jobs/retry_all?filter%5Bjob_class%5D=MailJob"
      expect(page.find_link("Retry All")["data-confirm"]).to eq "Retry all 2 failed jobs?"
    end

    it "notes when filtering stopped at the scan limit" do
      ActiveAdmin::Jobs.scan_limit = 2
      get "/admin/failed_jobs", params: { filter: { job_class: "MailJob" } }

      expect(page).to have_css ".flash", text: "Filtered within the newest 2 failures only."
      expect(listed_arguments).to eq %w[c]
      expect(page.find_link("Clear All")["data-confirm"]).to include "all matching failures will be affected"
    end

    it "does not note truncation without filters" do
      ActiveAdmin::Jobs.scan_limit = 2
      get "/admin/failed_jobs"

      expect(page).to have_no_css ".flash"
      expect(page).to have_css "tbody tr", count: 3
    end
  end

  describe "collection actions" do
    it "retries the filtered jobs and returns to the filtered list" do
      post "/admin/failed_jobs/retry_all", params: { filter: { job_class: "MailJob" } }

      expect(response).to redirect_to("/admin/failed_jobs?filter%5Bjob_class%5D=MailJob")
      expect(flash[:notice]).to eq "2 jobs retried."
      expect(failed_arguments).to eq %w[b]
    end

    it "clears the filtered jobs" do
      delete "/admin/failed_jobs/clear_all", params: { filter: { exception_class: "KeyError" } }

      expect(flash[:notice]).to eq "2 jobs removed."
      expect(failed_arguments).to eq %w[a]
    end
  end

  describe "stats" do
    it "links from the index" do
      get "/admin/failed_jobs"
      expect(page).to have_link "Failure Stats", href: "/admin/failed_jobs/stats"
    end

    it "counts failures by class and exception" do
      get "/admin/failed_jobs/stats"

      expect(page).to have_css "#page_title", text: "Failure Stats"
      rows = page.all("table.failure-stats").first.all("tbody tr").map { |row| row.all("td").map(&:text) }
      expect(rows).to eq [
        %w[MailJob 2 1 1 1 2 2],
        %w[SyncJob 1 0 1 1 1 1],
        %w[Total 3 1 2 2 3 3]
      ]
    end

    it "links counts to the filtered list" do
      get "/admin/failed_jobs/stats"

      expect(page).to have_link "1", href: "/admin/failed_jobs?filter%5Bjob_class%5D=MailJob&filter%5Bnewer_than%5D=1"
      expect(page).to have_link "2", href: "/admin/failed_jobs?filter%5Bexception_class%5D=KeyError"
      expect(page).to have_link "3", href: "/admin/failed_jobs?filter%5Bnewer_than%5D=72"
    end

    it "notes when counts stopped at the scan limit" do
      ActiveAdmin::Jobs.scan_limit = 2
      get "/admin/failed_jobs/stats"

      expect(page).to have_css ".jobs-truncated", text: "newest 2 failures"
    end
  end
end
