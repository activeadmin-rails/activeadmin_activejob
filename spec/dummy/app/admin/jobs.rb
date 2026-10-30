# frozen_string_literal: true

ActiveAdmin.configure_page "Jobs" do |config|
  ActiveAdmin::Jobs::Config.overview(config)
end
