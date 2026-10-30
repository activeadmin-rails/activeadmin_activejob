# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Queues" do
  let(:page) { Capybara.string(response.body) }

  before do
    enqueue_jobs("a", "b")
    enqueue_jobs("c", queue: "mail.high")
  end

  it "lists queues with sizes and links to their jobs" do
    get "/admin/queues"

    expect(page).to have_css "td.col-size", text: "2"
    expect(page).to have_link "mail.high", href: "/admin/queued_jobs?queue=mail.high"
    expect(page).to have_link "Clear", href: "/admin/queues/mail%252Ehigh"
  end

  it "removes a queue with its jobs" do
    delete "/admin/queues/mail%252Ehigh"

    expect(response).to redirect_to "/admin/queues"
    expect(flash[:notice]).to eq "Queue mail.high removed with 1 job."
    expect(Resque.queues).to eq ["default"]
  end

  it "redirects when the queue is gone" do
    delete "/admin/queues/missing"

    expect(response).to redirect_to "/admin/queues"
    expect(flash[:alert]).to eq "The queue is no longer present."
  end
end
