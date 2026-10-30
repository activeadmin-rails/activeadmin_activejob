# frozen_string_literal: true

require "resque"
require "activeadmin/jobs/adapters/resque/payload"
require "activeadmin/jobs/adapters/resque/failures"
require "activeadmin/jobs/adapters/resque/queues"
require "activeadmin/jobs/adapters/resque/workers"

module ActiveAdmin
  module Jobs
    module Adapters
      # Backend adapter for Resque (and the ActiveJob :resque queue adapter).
      #
      # Reads and writes Resque's Redis keys directly: Resque's own failure API
      # addresses entries by list index, which is unsafe under concurrent
      # changes (see Failures).
      class Resque < Base
        include Payload
        include Failures
        include Queues
        include Workers

        def supports?(feature)
          feature == :workers
        end

        def count_jobs(query)
          case query.status
          when :failed then count_failures(query)
          when :pending then count_pending(query)
          else unsupported_status(query)
          end
        end

        def fetch_jobs(query)
          case query.status
          when :failed then fetch_failures(query)
          when :pending then fetch_pending(query)
          else unsupported_status(query)
          end
        end

        def find_job(id, query)
          case query.status
          when :failed then find_failure(id)
          when :pending then find_pending(id)
          else unsupported_status(query)
          end
        end

        def retry_job(job)
          case job
          when FailedJob then retry_failure(job)
          else unsupported_status(job.class)
          end
        end

        def discard_job(job)
          case job
          when FailedJob then discard_failure(job)
          when QueuedJob then discard_pending(job)
          else unsupported_status(job.class)
          end
        end

        def retry_all(query)
          case query.status
          when :failed then retry_failures(query)
          else unsupported_status(query)
          end
        end

        def discard_all(query)
          case query.status
          when :failed then discard_failures(query)
          else unsupported_status(query)
          end
        end

        private

        # Redis::Namespace's WATCH and MULTI blocks yield un-namespaced
        # connections, so transactions use the underlying client and full keys.
        def redis
          ::Resque.redis.redis
        end

        def key(name)
          "#{::Resque.redis.full_namespace}:#{name}"
        end

        def unsupported_status(query)
          raise NotImplementedError, "#{self.class.name} does not support #{query.status} jobs yet"
        end
      end
    end
  end
end
