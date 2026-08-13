# frozen_string_literal: true

require "test_helper"

module Availability
  class DayPartTest < ActiveSupport::TestCase
    test "groups slots into morning afternoon and evening in that order" do
      slots = [
        slot_at(18, "Court 1"),
        slot_at(8, "Court 1"),
        slot_at(13, "Court 1"),
        slot_at(9, "Court 1")
      ]

      grouped = DayPart.group(slots)

      assert_equal [ "Morning", "Afternoon", "Evening" ], grouped.map(&:first)
      assert_equal [ 8, 9 ], grouped[0].last.map { |slot| slot.starts_at.hour }
      assert_equal [ 13 ], grouped[1].last.map { |slot| slot.starts_at.hour }
      assert_equal [ 18 ], grouped[2].last.map { |slot| slot.starts_at.hour }
    end

    test "omits empty day parts" do
      slots = [ slot_at(19, "Court 1") ]

      grouped = DayPart.group(slots)

      assert_equal [ "Evening" ], grouped.map(&:first)
    end

    test "treats late-night hours as evening" do
      assert_equal "Evening", DayPart.name_for(Time.zone.local(2026, 6, 14, 1, 0))
      assert_equal "Morning", DayPart.name_for(Time.zone.local(2026, 6, 14, 8, 0))
      assert_equal "Afternoon", DayPart.name_for(Time.zone.local(2026, 6, 14, 12, 0))
      assert_equal "Evening", DayPart.name_for(Time.zone.local(2026, 6, 14, 17, 0))
    end

    private

    def slot_at(hour, court)
      starts_at = Time.zone.local(2026, 6, 14, hour, 0)
      Slot.new(starts_at:, ends_at: starts_at + 1.hour, court:)
    end
  end
end
