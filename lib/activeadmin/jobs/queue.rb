# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # A queue in the backend, with the number of jobs waiting in it.
    class Queue
      include ActiveModel::Model

      attr_accessor :name, :size, :paused
    end
  end
end
