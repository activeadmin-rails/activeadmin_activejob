# frozen_string_literal: true

ActiveAdmin.configure_resource ActiveAdmin::Jobs::FailedJob, as: "FailedJob" do |config|
  ActiveAdmin::Jobs::Config.failed_jobs(config)
end
