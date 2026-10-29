# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Registry of backend adapters, keyed by ActiveJob queue adapter name.
    #
    #   ActiveAdmin::Jobs::Adapters.register(:resque) { MyResqueAdapter.new }
    #
    # The block is called lazily, so registering an adapter does not load its backend.
    module Adapters
      class UnsupportedAdapter < Error; end

      @factories = {}

      class << self
        def register(name, &factory)
          @factories[name.to_sym] = factory
        end

        def unregister(name)
          @factories.delete(name.to_sym)
        end

        def registered?(name)
          @factories.key?(name.to_sym)
        end

        def lookup(name)
          factory = @factories.fetch(name.to_sym) do
            raise UnsupportedAdapter, "No ActiveAdmin::Jobs adapter registered for #{name.inspect}"
          end
          factory.call
        end
      end
    end
  end
end
