# activeadmin_activejob

An [activeadmin-rails](https://github.com/activeadmin-rails/activeadmin-rails) plugin
for monitoring and retrying background jobs (ActiveJob), rendered as Active Admin
resources. It is intended to replace resque-web.

ActiveJob has no API for listing or acting on enqueued or failed jobs, so the plugin
talks to the queue backend through an adapter. Resque is the only backend planned
for now.

## Configuration

```ruby
# config/initializers/active_admin_jobs.rb
ActiveAdmin::Jobs.configure do |config|
  config.adapter_name = :resque  # defaults to config.active_job.queue_adapter
  config.scan_limit = 5_000      # max entries read for in-memory filters
  config.remove_on_retry = false # true: remove failed jobs on retry instead of marking them retried
end
```

Backend adapters subclass `ActiveAdmin::Jobs::Adapters::Base` and are registered by name:

```ruby
ActiveAdmin::Jobs::Adapters.register(:my_queue) { MyQueueAdapter.new }
```

## Development

The plugin currently depends on unreleased activeadmin-rails changes (branch
`feature/non-ar-resources`). The Gemfiles expect a checkout at `../activeadmin-rails`;
set `ACTIVEADMIN_RAILS_PATH` to use another location.

Specs need Redis. They flush database 15 of `REDIS_URL` (default
`redis://localhost:6379/15`).

```sh
bundle exec rake                                   # Sprockets (default Gemfile)

export BUNDLE_GEMFILE=$PWD/gemfiles/propshaft.gemfile
(cd spec/dummy && RAILS_ENV=test bundle exec rails dartsass:build)
bundle exec rake                                   # Propshaft
```

Delete `spec/dummy/app/assets/builds/*` before switching back to Sprockets; the
compiled CSS there otherwise shadows the Sprockets stylesheets.

## License

MIT
