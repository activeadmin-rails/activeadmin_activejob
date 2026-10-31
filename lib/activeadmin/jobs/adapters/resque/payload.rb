# frozen_string_literal: true

require "digest/sha1"
require "time"

module ActiveAdmin
  module Jobs
    module Adapters
      class Resque < Base
        # Decoding of Resque payloads, unwrapping ActiveJob's JobWrapper.
        module Payload
          JOB_WRAPPER = "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"

          private

          # Record id for a stored entry: its position (a hint, which concurrent
          # changes can invalidate) and a digest of its content (which identifies it).
          def entry_id(json, position)
            "#{position}-#{digest(json)}"
          end

          def parse_entry_id(id)
            position, digest = id.to_s.split("-", 2)
            return [nil, position] if digest.nil?

            [Integer(position, exception: false), digest]
          end

          def digest(json)
            Digest::SHA1.hexdigest(json)[0, 16]
          end

          # Job attributes from a Resque payload ({"class" => ..., "args" => [...]}).
          def payload_attributes(payload)
            payload ||= {}
            data = Array(payload["args"]).first
            if payload["class"] == JOB_WRAPPER && data.is_a?(Hash)
              {
                job_class: data["job_class"],
                job_id: data["job_id"],
                queue_name: data["queue_name"],
                arguments: ActiveAdmin::Jobs.filter_arguments(data["arguments"]),
                executions: data["executions"],
                enqueued_at: parse_time(data["enqueued_at"]),
                scheduled_at: parse_time(data["scheduled_at"])
              }
            else
              { job_class: payload["class"], arguments: ActiveAdmin::Jobs.filter_arguments(payload["args"]) }
            end
          end

          # The payload to requeue on retry. With ActiveAdmin::Jobs.reset_executions,
          # an ActiveJob job's execution counts are reset so that its retry_on
          # handlers retry it again rather than counting earlier attempts.
          def retry_payload(payload)
            data = Array(payload["args"]).first
            return payload unless ActiveAdmin::Jobs.reset_executions
            return payload unless payload["class"] == JOB_WRAPPER && data.is_a?(Hash)

            payload.merge("args" => [data.merge("executions" => 0, "exception_executions" => {}),
                                     *payload["args"].drop(1)])
          end

          # Resque writes times as local time strings, ActiveJob as ISO 8601.
          def parse_time(value)
            return if value.blank?

            time = value.is_a?(Numeric) ? Time.at(value).getlocal : Time.parse(value.to_s).getlocal
            Time.zone ? time.in_time_zone : time
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
