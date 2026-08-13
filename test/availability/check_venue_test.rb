# frozen_string_literal: true

require "test_helper"

module Availability
  class CheckVenueTest < ActiveSupport::TestCase
    setup { Rails.cache.clear }

    test "returns matching slots for a venue" do
      venue = VenueCatalog.find("pickle_village")
      search = Search.build(date: "2026-06-14", play_time: "07:00", play_time_end: "16:00")
      stub_rezerv(venue)

      result = CheckVenue.call(venue:, search:)

      assert_nil result.error
      assert result.slots.any?
      assert_equal venue.id, result.venue.id
      assert result.checked_at.present?
    end

    test "returns no slots when the play window has no match" do
      venue = VenueCatalog.find("pickle_village")
      search = Search.build(date: "2026-06-14", play_time: "10:00", play_time_end: "16:00")
      stub_rezerv(venue)

      result = CheckVenue.call(venue:, search:)

      assert_nil result.error
      assert_empty result.slots
    end

    test "returns an error result when the booking platform fails" do
      venue = VenueCatalog.find("pickle_village")
      search = Search.build(date: "2026-06-14", play_time: "07:00", play_time_end: "16:00")
      stub_request(:get, /customer-api\.rezerv\.co/).to_return(status: 500, body: "nope")

      result = CheckVenue.call(venue:, search:)

      assert_equal "HTTP 500", result.error
      assert_empty result.slots
    end

    test "reuses cached slots for the same venue and date" do
      venue = VenueCatalog.find("pickle_village")
      morning = Search.build(date: "2026-06-14", play_time: "07:00", play_time_end: "10:00")
      afternoon = Search.build(date: "2026-06-14", play_time: "10:00", play_time_end: "16:00")
      stub_rezerv(venue)

      first = CheckVenue.call(venue:, search: morning)
      second = CheckVenue.call(venue:, search: afternoon)

      assert first.slots.any?
      assert_empty second.slots
      assert_equal first.checked_at, second.checked_at
      assert_requested :get, /customer-api\.rezerv\.co/, times: 1
    end

    test "does not cache a failed check" do
      venue = VenueCatalog.find("pickle_village")
      search = Search.build(date: "2026-06-14", play_time: "07:00", play_time_end: "16:00")
      stub_request(:get, /customer-api\.rezerv\.co/)
        .to_return(status: 500, body: "nope")
        .then
        .to_return(status: 200, body: file_fixture("rezerv_pickle_village_2026-06-14.json").read)

      failed = CheckVenue.call(venue:, search:)
      recovered = CheckVenue.call(venue:, search:)

      assert_equal "HTTP 500", failed.error
      assert_nil recovered.error
      assert recovered.slots.any?
    end

    private

    def stub_rezerv(venue)
      stub_request(:get, /customer-api\.rezerv\.co\/v3\/appt-schedule\/timeslot_calendar/)
        .with(headers: { "Origin" => venue.config.fetch("origin") })
        .to_return(status: 200, body: file_fixture("rezerv_pickle_village_2026-06-14.json").read)
    end
  end
end
