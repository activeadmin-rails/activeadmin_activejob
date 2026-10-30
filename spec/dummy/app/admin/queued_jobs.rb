# frozen_string_literal: true

ActiveAdmin.configure_resource ActiveAdmin::Jobs::QueuedJob, as: "QueuedJob" do |config|
  ActiveAdmin::Jobs::Config.queued_jobs(config)
end
