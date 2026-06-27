# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class CourtogoAdapterTest < ActiveSupport::TestCase
      test "returns available slots from courtogo supabase and blocked-times data" do
        venue = VenueCatalog.find("pickle_point")
        search = Search.new(
          date: Date.new(2026, 6, 28),
          play_time: Time.zone.local(2026, 6, 28, 10, 0),
          play_time_end: Time.zone.local(2026, 6, 28, 16, 0)
        )

        stub_courtogo_requests(venue)

        slots = CourtogoAdapter.new.fetch_slots(venue, search)

        assert_includes slots.map(&:court), "Court 1"
        assert slots.any? { |slot| slot.starts_at.hour == 8 && slot.court == "Court 1" }
        assert_not slots.any? { |slot| slot.starts_at.hour == 10 && slot.court == "Court 1" }
        assert_not slots.any? { |slot| slot.starts_at.hour == 12 && slot.court == "Court 1" }
        assert_not slots.any? { |slot| slot.starts_at.hour == 13 && slot.court == "Court 1" }
        assert slots.any? { |slot| slot.starts_at.hour == 14 && slot.court == "Court 1" }
      end

      private

      def stub_courtogo_requests(venue)
        venue_id = venue.config.fetch("venue_id")

        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/courts})
          .to_return(status: 200, body: file_fixture("courtogo_pickle_point_courts.json").read)

        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/venues})
          .to_return(status: 200, body: file_fixture("courtogo_pickle_point_venue.json").read)

        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/booking_slots})
          .to_return(status: 200, body: file_fixture("courtogo_pickle_point_bookings.json").read)

        stub_request(:get, %r{www\.courtogo\.com/api/venues/#{venue_id}/blocked-times})
          .to_return(status: 200, body: file_fixture("courtogo_pickle_point_blocked_times.json").read)
      end
    end
  end
end
