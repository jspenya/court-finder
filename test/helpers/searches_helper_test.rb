# frozen_string_literal: true

require "test_helper"

class SearchesHelperTest < ActionView::TestCase
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
