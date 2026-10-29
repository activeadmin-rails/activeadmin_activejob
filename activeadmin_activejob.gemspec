# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "activeadmin/jobs/version"

Gem::Specification.new do |spec|
  spec.name          = "activeadmin_activejob"
  spec.version       = ActiveAdmin::Jobs::VERSION
  spec.summary       = "ActiveJob monitoring for ActiveAdmin"
  spec.description   = "An Active Admin plugin to monitor and retry background jobs (ActiveJob), " \
                       "with pluggable queue backends (Resque)."
  spec.license       = "MIT"
  spec.authors       = ["Piers Chambers"]
  spec.email         = ["piers@varyonic.com"]
  spec.homepage      = "https://github.com/activeadmin-rails/activeadmin_activejob"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files         = Dir["{app,config,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.2.0"

  spec.add_dependency "activeadmin-rails", ">= 1.8"
  spec.add_dependency "activejob", ">= 7.1"
end
