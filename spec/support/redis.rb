# frozen_string_literal: true

# Each example starts with an empty Resque database (see spec/dummy/config/initializers/resque.rb).
RSpec.configure do |config|
  config.before do
    Resque.redis.redis.flushdb
    ActiveAdmin::Jobs.reset!
  end
end
