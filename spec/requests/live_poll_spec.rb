# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Live poll" do
  let(:page) { Capybara.string(response.body) }

  %w[/admin/jobs /admin/workers /admin/queued_jobs].each do |path|
    it "offers to poll #{path}" do
      get path

      expect(page).to have_link "Live Poll", href: "#{path}?poll=1"
      expect(page).to have_no_css "#jobs_live_poll", visible: :all
    end
  end

  it "polls while the poll parameter is set, keeping other parameters" do
    enqueue_jobs("a", queue: "mail")
    get "/admin/queued_jobs", params: { queue: "mail", poll: 1 }

    expect(page).to have_link "Stop Live Poll", href: "/admin/queued_jobs?queue=mail"
    expect(page).to have_css "#jobs_live_poll", visible: :all
  end

  it "uses the configured interval" do
    ActiveAdmin::Jobs.poll_interval = 5
    get "/admin/jobs", params: { poll: 1 }

    expect(page).to have_css "#jobs_live_poll[data-interval='5000']", visible: :all
  end

  it "loads the gem's script and stylesheet" do
    get "/admin/jobs"

    expect(page).to have_css "script[src*='active_admin_jobs']", visible: :all
    expect(page).to have_css "link[rel=stylesheet][href*='active_admin_jobs']", visible: :all
  end

  it "is not offered for failed jobs" do
    get "/admin/failed_jobs", params: { poll: 1 }

    expect(page).to have_no_link "Live Poll"
    expect(page).to have_no_css "#jobs_live_poll", visible: :all
  end
end
