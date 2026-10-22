# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class KourtsuiteAdapterTest < ActiveSupport::TestCase
      setup do
        @venue = VenueCatalog.find("top_pick")
        @search = Search.build(date: "2026-06-14", play_time: "06:00", play_time_end: "23:00")
        @url = "#{KourtsuiteAdapter::BASE_URL}/tenants/T649/availability?date=2026-06-14"
      end

      test "search checks Top Pick and excludes booked slots on each court" do
        stub_slots([
          { court: 1, timeSlot: "06:00-07:00", available: true },
          { court: 1, timeSlot: "07:00-08:00", available: false },
          { court: 2, timeSlot: "06:00-07:00", available: false },
          { court: 2, timeSlot: "07:00-08:00", available: true }
        ])

        result = CheckVenue.call(venue: @venue, search: @search)

        assert_nil result.error
        assert_equal [ "Court 1", "Court 2" ], result.slots.map(&:court)
        assert_equal [ 6, 7 ], result.slots.map { |slot| slot.starts_at.hour }
        assert_equal Time.zone.local(2026, 6, 14, 6), result.slots.first.starts_at
        assert_equal 1.hour, result.slots.first.ends_at - result.slots.first.starts_at
        assert_equal "https://toppickcdo.com/#booking", result.venue.booking_url
      end

      test "midnight slot ends on the following date" do
        stub_slots([ { court: 2, timeSlot: "23:00-00:00", available: true } ])

        slots = KourtsuiteAdapter.new.fetch_slots(@venue, @search)

        assert_equal 1, slots.size
        assert_equal Time.zone.local(2026, 6, 14, 23), slots.first.starts_at
        assert_equal Time.zone.local(2026, 6, 15), slots.first.ends_at
      end

      test "no available slots returns an empty result" do
        stub_slots([ { court: 1, timeSlot: "06:00-07:00", available: false } ])
        assert_empty KourtsuiteAdapter.new.fetch_slots(@venue, @search)
      end

      test "API failure produces an error result" do
        stub_request(:get, @url).to_return(status: 503)
        result = CheckVenue.call(venue: @venue, search: @search)
        assert_equal "HTTP 503", result.error
      end

      private

      def stub_slots(slots)
        stub_request(:get, @url).to_return(body: { data: { slots: } }.to_json)
      end
    end
  end
end
