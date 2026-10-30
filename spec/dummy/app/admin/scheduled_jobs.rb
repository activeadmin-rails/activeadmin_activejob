# frozen_string_literal: true

ActiveAdmin.configure_resource ActiveAdmin::Jobs::ScheduledJob, as: "ScheduledJob" do |config|
  ActiveAdmin::Jobs::Config.scheduled_jobs(config)
end
