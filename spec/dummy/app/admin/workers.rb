# frozen_string_literal: true

ActiveAdmin.configure_resource ActiveAdmin::Jobs::Worker, as: "Worker" do |config|
  ActiveAdmin::Jobs::Config.workers(config)
end
