# activeadmin_activejob

An [activeadmin-rails](https://github.com/activeadmin-rails/activeadmin-rails) plugin
for monitoring and retrying background jobs (ActiveJob), rendered as Active Admin
resources. It is intended to replace resque-web.

ActiveJob has no API for listing or acting on enqueued or failed jobs, so the plugin
talks to the queue backend through an adapter. Resque is the only backend planned
for now.

## Usage

Each screen is an Active Admin resource backed by a controller you subclass in
your Active Admin namespace (here `admin`).

### Failed Jobs

Lists failed jobs newest first, with retry and remove per job, as a batch action,
and for the whole list ("Retry All", "Clear Retried", "Clear All").

```ruby
# app/controllers/admin/failed_jobs_controller.rb
class Admin::FailedJobsController < ActiveAdmin::Jobs::FailedJobsController
end

# app/admin/failed_jobs.rb
ActiveAdmin.configure_resource ActiveAdmin::Jobs::FailedJob, as: "FailedJob" do |config|
  ActiveAdmin::Jobs::Config.failed_jobs(config)
  # config.menu_item_options = { parent: "Jobs" }
end
```

Override `app/views/admin/failed_jobs/_index_as_table.html.arb` or `_show.html.arb`
to customise the pages.

Retrying requeues the job's original Resque payload (no ActiveJob callbacks run)
and marks the failure retried, as resque-web does. "Retry All" retries every
failed job, oldest first, including those already retried.

Authorization subjects are the resource classes (e.g. `ActiveAdmin::Jobs::FailedJob`).
Besides the standard actions, retrying is authorized as `:retry`; removing is
`ActiveAdmin::Auth::DESTROY`.

Job arguments are shown with `Rails.application.config.filter_parameters` masked.

Only Resque's Redis failure backend (alone or first in `Resque::Failure::Multiple`)
is supported.

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
