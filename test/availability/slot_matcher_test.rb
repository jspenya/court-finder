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
