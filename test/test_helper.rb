# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    setup do
      travel_to Time.zone.local(2026, 6, 13, 10, 0, 0)
    end
  end
end
