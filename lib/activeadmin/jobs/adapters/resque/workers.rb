# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    module Adapters
      class Resque < Base
        # Registered workers, read in one pipeline.
        module Workers
          WORKER_KEYS = %w[worker:%s worker:%s:started stat:processed:%s stat:failed:%s].freeze

          def workers
            ids = redis.smembers(key("workers")).sort
            return [] if ids.empty?

            *values, heartbeats = redis.pipelined do |pipe|
              ids.each { |id| WORKER_KEYS.each { |format| pipe.get(key(format % id)) } }
              pipe.hgetall(key("workers:heartbeat"))
            end
            ids.zip(values.each_slice(WORKER_KEYS.size)).map do |id, worker_values|
              build_worker(id, *worker_values, heartbeats[id])
            end
          end

          def stats
            info = ::Resque.info
            redis_info = redis.info
            info.merge(
              redis_version: redis_info["redis_version"],
              redis_uptime_in_days: redis_info["uptime_in_days"],
              redis_connected_clients: redis_info["connected_clients"],
              redis_used_memory: redis_info["used_memory_human"]
            )
          end

          private

          def build_worker(id, payload, started, processed, failed, heartbeat) # rubocop:disable Metrics/ParameterLists
            host, pid, queues = id.split(":", 3)
            job = payload ? ::Resque.decode(payload) : {}
            attributes = job.any? ? payload_attributes(job["payload"]) : {}
            Worker.new(
              id:, host:, pid:, queues: queues.to_s.split(","),
              started_at: parse_time(started), heartbeat_at: parse_time(heartbeat),
              processed: processed.to_i, failed: failed.to_i,
              job_class: attributes[:job_class], job_id: attributes[:job_id], arguments: attributes[:arguments],
              job_queue: job["queue"], run_at: parse_time(job["run_at"])
            )
          end
        end
      end
    end
  end
end
