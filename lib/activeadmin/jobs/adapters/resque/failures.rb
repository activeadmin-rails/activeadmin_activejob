# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    module Adapters
      class Resque < Base
        # Failed jobs in Resque's Redis failure list.
        #
        # Entries are identified by position plus content digest (Payload#entry_id).
        # The digest ignores +retried_at+, so marking a job retried keeps its id.
        # Before changing an entry by position the adapter checks, under WATCH, that
        # the stored entry is unchanged, and looks for it again if it has moved.
        module Failures
          FAILED = "failed"
          SCAN_CHUNK = 1_000
          MAX_ATTEMPTS = 3
          REMOVED = "activeadmin-jobs:removed"

          private

          def count_failures(query)
            return redis.llen(failed_key) if query.filters.empty?

            scan_failures(query).count
          end

          # Newest first.
          def fetch_failures(query)
            if query.filters.empty?
              page_failures(query.offset_value, query.limit_value)
            else
              jobs = scan_failures(query).drop(query.offset_value)
              query.limit_value ? jobs.first(query.limit_value) : jobs
            end
          end

          def find_failure(id)
            position, digest = parse_entry_id(id)
            json = redis.lindex(failed_key, position) if position
            return build_failure(json, position) if json && failure_digest(json) == digest

            each_failure(limit: ActiveAdmin::Jobs.scan_limit) do |entry, pos|
              return build_failure(entry, pos) if failure_digest(entry) == digest
            end
            nil
          end

          # Requeues the job's payload and removes the entry, or marks it retried
          # unless ActiveAdmin::Jobs.remove_on_retry.
          def retry_failure(job)
            entry = ::Resque.decode(job.raw)
            queue = entry["queue"]
            transact_failure(job) do |transaction, position|
              transaction.sadd(key("queues"), [queue])
              transaction.rpush(key("queue:#{queue}"), ::Resque.encode(retry_payload(entry["payload"])))
              if ActiveAdmin::Jobs.remove_on_retry
                remove_failure_at(transaction, position)
              else
                # Resque's format, in local time.
                retried = entry.merge("retried_at" => Time.now.getlocal.strftime("%Y/%m/%d %H:%M:%S"))
                transaction.lset(failed_key, position, ::Resque.encode(retried))
              end
            end
          end

          def discard_failure(job)
            check_failure_backend!
            redis.lrem(failed_key, 1, job.raw).positive?
          end

          # Retries matching jobs oldest first, so they are requeued in failure
          # order. When marking retried, retries every job, as resque-web does;
          # when removing, skips entries marked retried by another tool.
          def retry_failures(query)
            jobs = each_failure.map { |json, pos| build_failure(json, pos) }.reverse
            removed = 0
            jobs.count do |job|
              next false unless retry_all?(job, query.filters)

              # Removing an entry on retry shifts later entries down.
              job.position -= removed
              retry_failure(job).tap { |retried| removed += 1 if retried && ActiveAdmin::Jobs.remove_on_retry }
            end
          end

          def discard_failures(query)
            return clear_failures if query.filters.empty?

            entries = each_failure.filter_map { |json, _| json if matches?(build_failure(json, nil), query.filters) }
            redis.pipelined { |pipe| entries.each { |json| pipe.lrem(failed_key, 1, json) } }.sum
          end

          def clear_failures
            check_failure_backend!
            count, = redis.multi do |transaction|
              transaction.llen(failed_key)
              transaction.del(failed_key)
            end
            count
          end

          def page_failures(offset, limit)
            check_failure_backend!
            last = redis.llen(failed_key) - 1 - offset
            return [] if last.negative?

            first = limit ? [last - limit + 1, 0].max : 0
            redis.lrange(failed_key, first, last).each_with_index.map do |json, i|
              build_failure(json, first + i)
            end.reverse
          end

          # Bounded by ActiveAdmin::Jobs.scan_limit.
          def scan_failures(query)
            each_failure(limit: ActiveAdmin::Jobs.scan_limit)
              .map { |json, pos| build_failure(json, pos) }
              .select { |job| matches?(job, query.filters) }
          end

          # Yields each entry and its position, newest first.
          def each_failure(limit: nil)
            return enum_for(:each_failure, limit:) unless block_given?

            check_failure_backend!
            last = redis.llen(failed_key) - 1
            remaining = limit || Float::INFINITY
            while last >= 0 && remaining.positive?
              first = [last - SCAN_CHUNK + 1, 0].max
              redis.lrange(failed_key, first, last).each_with_index.reverse_each do |json, i|
                break unless remaining.positive?

                remaining -= 1
                yield json, first + i
              end
              last = first - 1
            end
          end

          # Runs the block in a MULTI transaction once the job's entry is verified
          # at its position, looking the entry up again if it has moved.
          #
          # @return [Boolean] whether the transaction ran
          def transact_failure(job)
            check_failure_backend!
            position = job.position
            MAX_ATTEMPTS.times do
              return false unless position

              result = redis.watch(failed_key) do |conn|
                if conn.lindex(failed_key, position) == job.raw
                  conn.multi { |transaction| yield transaction, position }
                else
                  conn.unwatch
                  :moved
                end
              end
              return true if result.is_a?(Array)

              # nil: another client changed the list during the transaction.
              position = locate_failure(job.raw) if result == :moved
            end
            false
          end

          def retry_all?(job, filters)
            matches?(job, filters) && !(job.retried? && ActiveAdmin::Jobs.remove_on_retry)
          end

          def locate_failure(json)
            each_failure(limit: ActiveAdmin::Jobs.scan_limit) { |entry, pos| return pos if entry == json }
            nil
          end

          def remove_failure_at(transaction, position)
            transaction.lset(failed_key, position, REMOVED)
            transaction.lrem(failed_key, 1, REMOVED)
          end

          # Unfiltered queries read the list directly; filtered ones scan at
          # most ActiveAdmin::Jobs.scan_limit entries.
          def failures_truncated?(query)
            limit = ActiveAdmin::Jobs.scan_limit
            query.filters.any? && limit.present? && redis.llen(failed_key) > limit
          end

          def matches?(job, filters)
            FailureFilter.match?(job, filters)
          end

          def build_failure(json, position)
            entry = ::Resque.decode(json)
            attributes = payload_attributes(entry["payload"])
            FailedJob.new(
              **attributes,
              id: "#{position}-#{failure_digest(entry)}",
              position:,
              raw: json,
              entry: ActiveAdmin::Jobs.filter_arguments(entry),
              queue_name: entry["queue"] || attributes[:queue_name],
              failed_at: parse_time(entry["failed_at"]),
              retried_at: parse_time(entry["retried_at"]),
              exception_class: entry["exception"],
              message: entry["error"],
              backtrace: Array(entry["backtrace"]),
              worker: entry["worker"]
            )
          end

          def failure_digest(entry)
            entry = ::Resque.decode(entry) if entry.is_a?(String)
            digest(::Resque.encode(entry.except("retried_at")))
          end

          def failed_key
            key(FAILED)
          end

          # Only the Redis failure backend (alone or first in Multiple, which
          # reads from its first backend) stores failures where we read them.
          def check_failure_backend!
            backend = ::Resque::Failure.backend
            backend = backend.classes.first if backend.name == "Resque::Failure::Multiple"
            return if backend.name == "Resque::Failure::Redis"

            raise UnsupportedBackend, "Failure backend #{backend.name} is not supported"
          end
        end
      end
    end
  end
end
