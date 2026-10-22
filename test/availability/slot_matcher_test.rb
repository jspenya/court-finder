# frozen_string_literal: true

require "test_helper"

module Availability
  class SlotMatcherTest < ActiveSupport::TestCase
    test "slot matches when it overlaps the play time window" do
      search = build_search(start_hour: 13, end_hour: 16)
      slot = Slot.new(
        starts_at: Time.zone.local(2026, 6, 14, 13, 0),
        ends_at: Time.zone.local(2026, 6, 14, 14, 0),
        court: nil
      )

      assert SlotMatcher.covers?(search, slot)
    end

    test "slot matches when it only overlaps the start of the window" do
      search = build_search(start_hour: 13, end_hour: 16)
      slot = Slot.new(
        starts_at: Time.zone.local(2026, 6, 14, 12, 0),
        ends_at: Time.zone.local(2026, 6, 14, 14, 0),
        court: nil
      )

      assert SlotMatcher.covers?(search, slot)
    end

    test "slot is excluded when it ends before the window starts" do
      search = build_search(start_hour: 13, end_hour: 16)
      slot = Slot.new(
        starts_at: Time.zone.local(2026, 6, 14, 11, 0),
        ends_at: Time.zone.local(2026, 6, 14, 12, 0),
        court: nil
      )

      assert_not SlotMatcher.covers?(search, slot)
    end

    test "slot matches when it starts at the window end" do
      search = build_search(start_hour: 13, end_hour: 16)
      slot = Slot.new(
        starts_at: Time.zone.local(2026, 6, 14, 16, 0),
        ends_at: Time.zone.local(2026, 6, 14, 17, 0),
        court: nil
      )

      assert SlotMatcher.covers?(search, slot)
    end

    test "slot is excluded when it starts after the window ends" do
      search = build_search(start_hour: 13, end_hour: 16)
      slot = Slot.new(
        starts_at: Time.zone.local(2026, 6, 14, 17, 0),
        ends_at: Time.zone.local(2026, 6, 14, 18, 0),
        court: nil
      )

      assert_not SlotMatcher.covers?(search, slot)
    end

    test "stacked morning and evening exclude the afternoon including boundary-only overlaps" do
      search = Search.build(date: "2026-06-14", play_time: "08:00",
        play_time_end: "00:00", day_parts: "morning,evening")
      slots = (7..23).map do |hour|
        Slot.new(starts_at: Time.zone.local(2026, 6, 14, hour),
          ends_at: Time.zone.local(2026, 6, 14, hour) + 1.hour, court: nil)
      end

      assert_equal [ 8, 9, 10, 11, 17, 18, 19, 20, 21, 22, 23 ],
        SlotMatcher.matching_slots(search, slots).map { |slot| slot.starts_at.hour }
    end

    test "a slot overlapping multiple selected periods appears once" do
      search = Search.build(date: "2026-06-14", play_time: "08:00",
        play_time_end: "17:00", day_parts: "morning,afternoon")
      slot = Slot.new(starts_at: Time.zone.local(2026, 6, 14, 11),
        ends_at: Time.zone.local(2026, 6, 14, 13), court: nil)

      assert_equal [ slot ], SlotMatcher.matching_slots(search, [ slot ])
    end

    private

    def build_search(start_hour:, end_hour:)
      Search.new(
        date: Date.new(2026, 6, 14),
        play_time: Time.zone.local(2026, 6, 14, start_hour, 0),
        play_time_end: Time.zone.local(2026, 6, 14, end_hour, 0)
      )
    end
  end
end
