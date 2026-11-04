# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Jobs tabs" do
  let(:page) { Capybara.string(response.body) }

  def tabs
    page.all("#jobs_tabs li").map { |tab| tab.text.squish }
  end

  def current_tab
    page.find("#jobs_tabs li.selected").text.squish
  end

  it "links every jobs screen, with counts" do
    fail_jobs("a")
    enqueue_jobs("b", "c")
    get "/admin/jobs"

    expect(tabs).to eq ["Overview", "Workers 0", "Failed Jobs 1", "Failure Stats", "Scheduled Jobs"]
    expect(page).to have_link "Failure Stats", href: "/admin/failed_jobs/stats"
    expect(page).to have_link "Overview", href: "/admin/jobs"
  end

  {
    "/admin/jobs" => "Overview",
    "/admin/queued_jobs" => "Overview",
    "/admin/workers" => "Workers 0",
    "/admin/failed_jobs" => "Failed Jobs 0",
    "/admin/failed_jobs/stats" => "Failure Stats",
    "/admin/scheduled_jobs" => "Scheduled Jobs"
  }.each do |path, tab|
    it "marks #{tab} current on #{path}" do
      get path

      expect(current_tab).to eq tab
    end
  end

  it "shows on show pages" do
    fail_jobs("a")
    get "/admin/failed_jobs/#{ActiveAdmin::Jobs::FailedJob.all.first.id}"

    expect(current_tab).to eq "Failed Jobs 1"
  end

  context "when not authorized to read a screen" do
    around do |example|
      namespace = ActiveAdmin.application.namespace(:admin)
      original = namespace.authorization_adapter
      namespace.authorization_adapter = Class.new(ActiveAdmin::AuthorizationAdapter) do
        def authorized?(action, subject = nil)
          !(action == ActiveAdmin::Auth::READ && subject == ActiveAdmin::Jobs::Worker)
        end
      end
      example.run
    ensure
      namespace.authorization_adapter = original
    end

    it "omits its tab" do
      get "/admin/jobs"

      expect(tabs).not_to include(a_string_starting_with("Workers"))
      expect(tabs).to include "Overview"
    end
  end
end
