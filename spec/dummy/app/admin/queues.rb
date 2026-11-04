# frozen_string_literal: true

ActiveAdmin.configure_resource ActiveAdmin::Jobs::Queue, as: "Queue" do |config|
  ActiveAdmin::Jobs::Config.queues(config)
  config.menu_item_options = false # reached through the jobs tabs
end
