# frozen_string_literal: true

ActiveAdmin.setup do |config|
  config.site_title = "Dummy"

  # Disable authentication for testing
  config.authentication_method = false
  config.current_user_method = false

  # Use default authorization adapter that allows all actions
  config.authorization_adapter = ActiveAdmin::AuthorizationAdapter

  config.comments = false
end
