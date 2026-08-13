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
end
