# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] = "test"

require "simplecov"
SimpleCov.start do
  add_filter %r{^/spec/}
end

require File.expand_path("dummy/config/environment.rb", __dir__)

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "capybara/rails"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.use_transactional_fixtures = true
  config.render_views = false
end
