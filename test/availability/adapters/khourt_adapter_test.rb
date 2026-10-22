# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class KhourtAdapterTest < ActiveSupport::TestCase
      setup do
        @venue = VenueCatalog.find("pikol")
        @search = Search.build(date: "2026-06-14", play_time: "08:00", play_time_end: "12:00")
        @courts = @venue.config.fetch("courts")
      end

      test "checks both courts and returns only available slots in Manila time" do
        stub_court(@courts.first, slots: [ slot(8), slot(9, status: "booked"), slot(10, status: "blocked"), slot(11, status: "past") ])
        stub_court(@courts.last, slots: [ slot(10), slot(11, status: "closed") ])

        result = CheckVenue.call(venue: @venue, search: @search)

        assert_nil result.error
        assert_equal [ "Blue Court", "Green Court" ], result.slots.map(&:court)
        assert_equal [ 8, 10 ], result.slots.map { |s| s.starts_at.hour }
        assert result.slots.all? { |s| s.starts_at.utc_offset == 8.hours && s.ends_at - s.starts_at == 1.hour }
      end

      test "preserves midnight rollover from UTC timestamps" do
        stub_court(@courts.first, slots: [ slot(23) ])
        stub_court(@courts.last, closed: true, slots: [])

        slots = KhourtAdapter.new.fetch_slots(@venue, @search)

        assert_equal 1, slots.size
        assert_equal Time.zone.local(2026, 6, 15), slots.first.ends_at
      end

      test "closed courts and empty availability return no slots" do
        stub_court(@courts.first, closed: true, slots: [ slot(8) ])
        stub_court(@courts.last, closed: false, slots: [])

        result = CheckVenue.call(venue: @venue, search: @search)

        assert_nil result.error
        assert_empty result.slots
      end

      test "one court failing returns an error rather than partial availability" do
        stub_court(@courts.first, slots: [ slot(8) ])
        stub_request(:get, court_url(@courts.last)).to_return(status: 503)

        result = CheckVenue.call(venue: @venue, search: @search)

        assert_equal "HTTP 503", result.error
        assert_empty result.slots
      end

      test "error and malformed responses return venue errors" do
        [ { error: "Unavailable" }, {}, "Maintenance", { slots: [ slot(8).merge(startIso: "invalid") ] } ].each do |payload|
          stub_court(@courts.first, payload)

          result = CheckVenue.call(venue: @venue, search: @search)

          assert result.error.present?
          assert_empty result.slots
        end
      end

      private

      def slot(hour, status: "available")
        starts_at = Time.zone.local(2026, 6, 14, hour)
        { startIso: starts_at.utc.iso8601, endIso: (starts_at + 1.hour).utc.iso8601, status: }
      end

      def court_url(court)
        "https://www.khourt.com/api/venues/pikol/public-availability?resourceId=#{court.fetch('id')}&date=2026-06-14"
      end

      def stub_court(court, payload)
        stub_request(:get, court_url(court)).to_return(body: payload.is_a?(String) ? payload : payload.to_json)
      end
    end
  end
end
