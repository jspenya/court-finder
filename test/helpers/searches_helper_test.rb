# frozen_string_literal: true

require "test_helper"

class SearchesHelperTest < ActionView::TestCase
  test "venue overview merges overlapping courts but preserves gaps" do
    time = Time.zone.local(2026, 6, 14, 13)
    slots = [
      Availability::Slot.new(starts_at: time + 3.hours, ends_at: time + 4.hours, court: "A"),
      Availability::Slot.new(starts_at: time, ends_at: time + 1.hour, court: "A"),
      Availability::Slot.new(starts_at: time + 30.minutes, ends_at: time + 2.hours, court: "B")
    ]
    result = Availability::SearchResult.new(venue: nil, slots:, error: nil, checked_at: time)

    assert_equal [ [ time, time + 2.hours ], [ time + 3.hours, time + 4.hours ] ], venue_availability_ranges(result)
    assert_equal 3, result.slots.size
  end

  test "all-day bars use Philippine midnight and stop at the day boundary" do
    date = Date.new(2026, 6, 14)
    midnight = date.in_time_zone
    search = Availability::Search.build(date: date.iso8601, play_time: "00:00", play_time_end: "00:00")

    assert_equal "left: 50.0%; width: 25.0%", availability_bar_style(midnight + 12.hours, midnight + 18.hours, search)
    assert_equal "left: 95.8333%; width: 4.1667%", availability_bar_style(midnight + 23.hours, midnight + 25.hours, search)
  end

  test "evening bar spans only 5 PM to midnight" do
    search = Availability::Search.build(date: "2026-06-14", play_time: "17:00", play_time_end: "00:00")

    assert_equal [ "5 PM", "8:30 PM", "12 AM" ], availability_axis_labels(search)
    assert_equal "left: 0.0%; width: 100.0%", availability_bar_style(search.play_time, search.play_time_end, search)
    assert_equal "left: 42.8571%; width: 14.2857%", availability_bar_style(search.play_time + 3.hours, search.play_time + 4.hours, search)
  end

  test "custom range clips overview while preserving individual court slots" do
    search = Availability::Search.build(date: "2026-06-14", play_time: "13:00", play_time_end: "15:00")
    slot = Availability::Slot.new(starts_at: search.play_time - 1.hour, ends_at: search.play_time_end + 1.hour, court: "A")
    result = Availability::SearchResult.new(venue: nil, slots: [ slot ], error: nil, checked_at: search.play_time)

    assert_equal [ "1 PM", "2 PM", "3 PM" ], availability_axis_labels(search)
    assert_equal "left: 0%; width: 100%", availability_bar_style(slot.starts_at, slot.ends_at, search)
    assert_equal [ [ search.play_time, search.play_time_end ] ], venue_availability_ranges(result, search:)
    assert_equal slot, result.slots.first
  end

  test "separate selected periods preserve the gap in the overview" do
    search = Availability::Search.build(date: "2026-06-14", play_time: "08:00", play_time_end: "00:00", day_parts: "morning,evening")
    slot = Availability::Slot.new(starts_at: search.play_time, ends_at: search.play_time_end, court: "A")
    result = Availability::SearchResult.new(venue: nil, slots: [ slot ], error: nil, checked_at: search.play_time)

    assert_equal search.time_windows, venue_availability_ranges(result, search:)
  end

  test "all-day window is labeled all day" do
    search = Availability::Search.build(date: "2026-06-14", play_time: "00:00", play_time_end: "00:00")

    assert_equal "all day", format_play_time_window(search)
  end

  test "venue location links to google maps" do
    venue = Availability::VenueCatalog.find("pickle_village")

    html = venue_location_link(venue)

    assert_includes html, "https://www.google.com/maps/search/"
    assert_includes html, venue.address
    assert_includes html, 'target="_blank"'
  end

  test "venue_frame_status reflects match, miss, and error" do
    venue = Availability::VenueCatalog.find("pickle_village")
    checked_at = Time.zone.now
    available = Availability::SearchResult.new(
      venue:,
      slots: [ Availability::Slot.new(starts_at: checked_at, ends_at: checked_at + 1.hour, court: "COURT 1") ],
      error: nil,
      checked_at:
    )
    empty = Availability::SearchResult.new(venue:, slots: [], error: nil, checked_at:)
    failed = Availability::SearchResult.new(venue:, slots: [], error: "Timed out", checked_at:)

    assert_equal "available", venue_frame_status(available)
    assert_equal "empty", venue_frame_status(empty)
    assert_equal "error", venue_frame_status(failed)
  end
end
