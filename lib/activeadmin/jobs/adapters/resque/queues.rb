# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    module Adapters
      class Resque < Base
        # Queues and the jobs waiting in them.
        #
        # Queued jobs are identified by position, content digest and queue, and
        # removed by exact value, so a stale position never removes another job.
        module Queues
          def queues
            names = redis.smembers(key("queues")).sort
            sizes = redis.pipelined { |pipe| names.each { |name| pipe.llen(queue_key(name)) } }
            names.zip(sizes).map { |name, size| ActiveAdmin::Jobs::Queue.new(name:, size:, paused: false) }
          end

          # Removes the queue and its jobs, as resque-web does. Workers watching
          # the queue keep polling it, and it reappears when a job is enqueued.
          def clear_queue(name)
            count, = redis.multi do |transaction|
              transaction.llen(queue_key(name))
              transaction.del(queue_key(name))
              transaction.srem(key("queues"), [name])
            end
            count
          end

          private

          def count_pending(query)
            queue = pending_queue(query) or return 0
            redis.llen(queue_key(queue))
          end

          # In the order they will run.
          def fetch_pending(query)
            queue = pending_queue(query) or return []
            first = query.offset_value
            last = query.limit_value ? first + query.limit_value - 1 : -1
            redis.lrange(queue_key(queue), first, last).each_with_index.map do |json, i|
              build_pending(json, first + i, queue)
            end
          end

          def find_pending(id)
            position, digest, queue = parse_pending_id(id)
            return unless queue

            json = redis.lindex(queue_key(queue), position) if position
            return build_pending(json, position, queue) if json && digest(json) == digest

            scan_pending(queue) { |entry, pos| return build_pending(entry, pos, queue) if digest(entry) == digest }
            nil
          end

          def discard_pending(job)
            redis.lrem(queue_key(job.queue_name), 1, job.raw).positive?
          end

          def scan_pending(queue)
            limit = ActiveAdmin::Jobs.scan_limit
            (0...limit).step(Failures::SCAN_CHUNK) do |first|
              last = [first + Failures::SCAN_CHUNK, limit].min - 1
              entries = redis.lrange(queue_key(queue), first, last)
              entries.each_with_index { |json, i| yield json, first + i }
              break if entries.size < Failures::SCAN_CHUNK
            end
          end

          def pending_queue(query)
            query.filters.each_key do |name|
              raise ArgumentError, "Unsupported queued job filter: #{name.inspect}" unless name == :queue
            end
            query.filters[:queue].presence
          end

          def build_pending(json, position, queue)
            payload = ::Resque.decode(json)
            QueuedJob.new(
              **payload_attributes(payload),
              id: "#{entry_id(json, position)}-#{queue}",
              position:,
              raw: json,
              entry: ActiveAdmin::Jobs.filter_arguments(payload),
              queue_name: queue
            )
          end

          def parse_pending_id(id)
            position, digest, queue = id.to_s.split("-", 3)
            [Integer(position, exception: false), digest, queue]
          end

          def queue_key(name)
            key("queue:#{name}")
          end
        end
      end
    end
  end
end
