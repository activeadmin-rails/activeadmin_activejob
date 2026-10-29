# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActiveAdmin::Jobs do
  describe ".adapter_name" do
    it "defaults to the ActiveJob queue adapter" do
      expect(described_class.adapter_name).to eq :resque
    end

    it "can be configured" do
      described_class.configure { |c| c.adapter_name = :other }
      expect(described_class.adapter_name).to eq :other
    end
  end

  describe ".adapter" do
    let(:adapter) { ActiveAdmin::Jobs::Adapters::Base.new }

    around do |example|
      ActiveAdmin::Jobs::Adapters.register(:fake) { adapter }
      example.run
    ensure
      ActiveAdmin::Jobs::Adapters.unregister(:fake)
    end

    it "looks up the configured adapter" do
      described_class.adapter_name = :fake
      expect(described_class.adapter).to equal adapter
    end

    it "raises for an unregistered adapter" do
      described_class.adapter_name = :unknown
      expect { described_class.adapter }.to raise_error(ActiveAdmin::Jobs::Adapters::UnsupportedAdapter, /:unknown/)
    end
  end

  describe ActiveAdmin::Jobs::Adapters::Base do
    subject(:adapter) { described_class.new }

    it "supports no optional features" do
      expect(described_class::FEATURES.map { |f| adapter.supports?(f) }).to all(be false)
    end

    it "requires subclasses to implement the contract" do
      expect { adapter.fetch_jobs(nil) }.to raise_error(NotImplementedError, /#fetch_jobs/)
    end
  end
end
