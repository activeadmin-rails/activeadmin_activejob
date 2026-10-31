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
and for the whole list ("Retry All", "Clear All").

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

Retrying requeues the job's original Resque payload (no ActiveJob enqueue
callbacks run) and removes the failure. ActiveJob execution counts are reset, so
`retry_on` retries the job again if it fails; set `reset_executions = false` to
keep them. "Retry All" retries every failed job, oldest first,
skipping any marked retried by resque-web; "Clear Retried" and a Retried At column
appear while such entries exist.

With `remove_on_retry = false`, retrying instead marks the failure retried, as
resque-web does, and "Retry All" retries every entry, including those already
retried.

A Filters sidebar narrows the list by job class, exception, queue, age ("Newer
Than" / "Older Than") and a regular expression matched against the failure entry
(with filtered parameters masked; each match times out after a second). "Retry
All", "Clear All" and "Clear Retried" then act on the matching jobs only.
"Failure Stats" counts failures by job class and by exception over the last hour,
3 hours, day, 3 days and week, linking each count to the filtered list, as
resque-cleaner does.

Filtering and stats read at most `scan_limit` failures, newest first, and the page
says so when there are more. Bulk actions on a filtered list still act on every
matching failure.

Authorization subjects are the resource classes (e.g. `ActiveAdmin::Jobs::FailedJob`).
Besides the standard actions, retrying is authorized as `:retry`; removing is
`ActiveAdmin::Auth::DESTROY`.

Job arguments are shown with `Rails.application.config.filter_parameters` masked.

Only Resque's Redis failure backend (alone or first in `Resque::Failure::Multiple`)
is supported.

### Queued Jobs, Scheduled Jobs, Queues, Workers and the Jobs overview

Register the other screens the same way, each with a controller subclass:

| Resource / page | Controller superclass | Configuration |
|---|---|---|
| `configure_resource ActiveAdmin::Jobs::QueuedJob, as: "QueuedJob"` | `ActiveAdmin::Jobs::QueuedJobsController` | `Config.queued_jobs(config)` |
| `configure_resource ActiveAdmin::Jobs::ScheduledJob, as: "ScheduledJob"` | `ActiveAdmin::Jobs::ScheduledJobsController` | `Config.scheduled_jobs(config)` |
| `configure_resource ActiveAdmin::Jobs::Queue, as: "Queue"` | `ActiveAdmin::Jobs::QueuesController` | `Config.queues(config)` |
| `configure_resource ActiveAdmin::Jobs::Worker, as: "Worker"` | `ActiveAdmin::Jobs::WorkersController` | `Config.workers(config)` |
| `configure_page "Jobs"` | `ActiveAdmin::Jobs::OverviewController` | `Config.overview(config)` |

- **Queued Jobs** lists one queue's jobs in the order they will run (`?queue=`,
  default the first queue), with a sidebar of queues. Jobs can be removed singly
  or in batches.
- **Scheduled Jobs** (needs resque-scheduler) lists delayed jobs soonest first,
  with "Enqueue Now" and remove per job and in batches, and "Clear All".
  Enqueuing now is authorized as `:enqueue_now`.
- **Queues** lists queue sizes. "Clear" removes a queue and its jobs, as resque-web does.
- **Workers** lists registered workers, working first, with their current jobs (read only).
- **Jobs** (overview page) shows queue sizes, failed and scheduled job counts, working
  workers and Resque/Redis statistics, linking to the screens that are registered.

Queue names and worker ids may contain dots; they are percent-encoded in URLs.

## Configuration

```ruby
# config/initializers/active_admin_jobs.rb
ActiveAdmin::Jobs.configure do |config|
  config.adapter_name = :resque  # defaults to config.active_job.queue_adapter
  config.scan_limit = 5_000      # max failures read for filters and stats
  config.remove_on_retry = true  # false: mark failed jobs retried instead (resque-web behaviour)
  config.reset_executions = true # false: keep ActiveJob execution counts on retry
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
