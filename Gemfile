# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Until the non-ActiveRecord resource support is released, build against a local
# checkout of activeadmin-rails on branch feature/non-ar-resources.
gem "activeadmin-rails", path: ENV.fetch("ACTIVEADMIN_RAILS_PATH", File.expand_path("../activeadmin-rails", __dir__))

group :development, :test do
  gem "capybara", "~> 3.39"
  gem "dartsass-sprockets"
  gem "puma", ">= 6.0"
  gem "rails", "~> 8.0"
  gem "redis", "~> 5.0"
  gem "resque", "~> 2.6"
  gem "resque-scheduler", "~> 4.10"
  gem "rspec-rails", "~> 8.0"
  gem "simplecov", "~> 0.22"
  gem "sqlite3", ">= 2.1"

  # Linters
  gem "rubocop"
  gem "rubocop-packaging"
  gem "rubocop-performance"
  gem "rubocop-rails"
  gem "rubocop-rspec"

  # Tools
  gem "pry-rails"
end

gem "csv"
gem "irb"
gem "logger"
gem "ostruct"
gem "rake", "~> 13.0"
