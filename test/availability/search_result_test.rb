# frozen_string_literal: true

require "test_helper"

module Availability
  class SearchResultTest < ActiveSupport::TestCase
    test "court schedules group slots by day part within each court" do
      venue = VenueCatalog.find("pickle_village")
      result = SearchResult.new(
        venue:,
        slots: [
          slot_at(18, "COURT 1"),
          slot_at(8, "COURT 1"),
          slot_at(13, "COURT 2")
        ],
        error: nil,
        checked_at: Time.zone.now
      )

      schedules = result.court_schedules

      assert_equal [ "COURT 1", "COURT 2" ], schedules.map(&:first)
      assert_equal [ "Morning", "Evening" ], schedules[0].last.map(&:first)
      assert_equal [ "Afternoon" ], schedules[1].last.map(&:first)
    end

    private

    def slot_at(hour, court)
      starts_at = Time.zone.local(2026, 6, 14, hour, 0)
      Slot.new(starts_at:, ends_at: starts_at + 1.hour, court:)
    end
  end
end
