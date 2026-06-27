# frozen_string_literal: true

require "test_helper"

module Availability
  class SearchTest < ActiveSupport::TestCase
    test "play time window searches overlapping slots" do
      search = Search.build(date: "2026-06-14", play_time: "13:00", play_time_end: "16:00")

      assert_equal Time.zone.local(2026, 6, 14, 13, 0), search.play_time
      assert_equal Time.zone.local(2026, 6, 14, 16, 0), search.play_time_end
    end

    test "rejects blank start time" do
      assert_raises(InvalidSearch) do
        Search.build(date: "2026-06-14", play_time: "", play_time_end: "16:00")
      end
    end

    test "rejects end time before start time" do
      assert_raises(InvalidSearch) do
        Search.build(date: "2026-06-14", play_time: "16:00", play_time_end: "13:00")
      end
    end
  end
end
