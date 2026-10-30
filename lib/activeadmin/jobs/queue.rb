# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # A queue in the backend, with the number of jobs waiting in it.
    class Queue
      include ActiveModel::Model

      attr_accessor :name, :size, :paused

      class << self
        def all
          ActiveAdmin::Jobs.adapter.queues
        end

        def find_by(conditions)
          name = conditions.to_h.symbolize_keys[:id]
          all.detect { |queue| queue.name == name }
        end
      end

      alias id name

      def persisted?
        true
      end

      def to_param
        Param.encode(name)
      end

      def display_name
        name
      end
    end
  end
end
