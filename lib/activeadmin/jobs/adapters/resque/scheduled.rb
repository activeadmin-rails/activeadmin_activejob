# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    module Adapters
      class Resque < Base
        # Delayed jobs stored by resque-scheduler: a sorted set of timestamps,
        # each with a list of jobs ("delayed:<timestamp>"), and for each job a
        # set of the lists holding it ("timestamps:<job>").
        #
        # Jobs are identified by timestamp, position and content digest, and
        # removed by exact value. resque-scheduler's own removal looks jobs up by
        # class, which misses ActiveJob jobs (all JobWrapper) in some versions.
        module Scheduled
          SCHEDULE = "delayed_queue_schedule"

          private

          def scheduler?
            defined?(::Resque::Scheduler) && ::Resque.respond_to?(:enqueue_at)
          end

          def count_scheduled(query)
            check_scheduler!(query)
            scheduled_sizes.sum { |_, size| size }
          end

          # Soonest first.
          def fetch_scheduled(query)
            check_scheduler!(query)
            slices = scheduled_slices(query.offset_value, query.limit_value)
            lists = redis.pipelined do |pipe|
              slices.each { |timestamp, first, last| pipe.lrange(delayed_key(timestamp), first, last) }
            end
            slices.zip(lists).flat_map do |(timestamp, first, _), jsons|
              jsons.each_with_index.map { |json, i| build_scheduled(json, timestamp, first + i) }
            end
          end

          def find_scheduled(id)
            timestamp, position, digest = id.to_s.split("-", 3)
            return unless timestamp && digest

            jsons = redis.lrange(delayed_key(timestamp), 0, -1)
            index = scheduled_index(jsons, Integer(position, exception: false), digest)
            build_scheduled(jsons[index], timestamp, index) if index
          end

          # The position hint if the job is still there, else wherever it is now.
          def scheduled_index(jsons, hint, digest)
            return hint if hint && jsons[hint] && digest(jsons[hint]) == digest

            jsons.index { |json| digest(json) == digest }
          end

          # Pushes the job to its queue now, removing it from the schedule.
          def enqueue_scheduled(job)
            item = ::Resque.decode(job.raw)
            queue = item["queue"] or raise ArgumentError, "Scheduled job has no queue"
            payload = ::Resque.encode(item.slice("class", "args"))
            transact_scheduled(job) do |transaction|
              transaction.sadd(key("queues"), [queue])
              transaction.rpush(key("queue:#{queue}"), payload)
            end
          end

          def discard_scheduled(job)
            transact_scheduled(job) { nil }
          end

          def discard_all_scheduled(query)
            check_scheduler!(query)
            count = count_scheduled(query)
            ::Resque.reset_delayed_queue
            count
          end

          # Removes the job from its timestamp's list and runs the block in the
          # same transaction, if the job is still there. Then drops the
          # timestamp from the schedule if its list is empty.
          def transact_scheduled(job)
            list = delayed_key(job.scheduled_at.to_i)
            result = redis.watch(list) do |conn|
              if conn.lpos(list, job.raw)
                conn.multi do |transaction|
                  transaction.lrem(list, 1, job.raw)
                  transaction.srem(key("timestamps:#{job.raw}"), [unprefixed(list)])
                  yield transaction
                end
              else
                conn.unwatch
                nil
              end
            end
            clean_up_timestamp(job.scheduled_at.to_i)
            result.is_a?(Array) && result.first.positive?
          end

          def clean_up_timestamp(timestamp)
            list = delayed_key(timestamp)
            redis.watch(list) do |conn|
              if conn.llen(list).zero?
                conn.multi do |transaction|
                  transaction.del(list)
                  transaction.zrem(key(SCHEDULE), timestamp.to_s)
                end
              else
                conn.unwatch
              end
            end
          end

          # [[timestamp, size], ...] soonest first.
          def scheduled_sizes
            timestamps = redis.zrange(key(SCHEDULE), 0, -1)
            sizes = redis.pipelined { |pipe| timestamps.each { |timestamp| pipe.llen(delayed_key(timestamp)) } }
            timestamps.zip(sizes)
          end

          # [[timestamp, first, last], ...] covering jobs offset...offset + limit.
          def scheduled_slices(offset, limit)
            remaining = limit || Float::INFINITY
            slices = []
            scheduled_sizes.each do |timestamp, size|
              break unless remaining.positive?
              next offset -= size if offset >= size

              count = [size - offset, remaining].min
              slices << [timestamp, offset, offset + count - 1]
              remaining -= count
              offset = 0
            end
            slices
          end

          def build_scheduled(json, timestamp, position)
            item = ::Resque.decode(json)
            attributes = payload_attributes(item)
            ScheduledJob.new(
              **attributes,
              id: "#{timestamp}-#{entry_id(json, position)}",
              position:,
              raw: json,
              entry: ActiveAdmin::Jobs.filter_arguments(item),
              queue_name: item["queue"] || attributes[:queue_name],
              scheduled_at: parse_time(timestamp.to_i)
            )
          end

          def delayed_key(timestamp)
            key("delayed:#{timestamp.to_i}")
          end

          def unprefixed(full_key)
            full_key.delete_prefix("#{::Resque.redis.full_namespace}:")
          end

          def check_scheduler!(query)
            unsupported_status(query) unless scheduler?
          end
        end
      end
    end
  end
end
