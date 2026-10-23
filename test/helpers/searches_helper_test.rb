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

  test "availability bars use Philippine midnight and stop at the day boundary" do
    date = Date.new(2026, 6, 14)
    midnight = date.in_time_zone

    assert_equal "left: 50.0%; width: 25.0%", availability_bar_style(midnight + 12.hours, midnight + 18.hours, date)
    assert_equal "left: 95.8333%; width: 4.1667%", availability_bar_style(midnight + 23.hours, midnight + 25.hours, date)
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
