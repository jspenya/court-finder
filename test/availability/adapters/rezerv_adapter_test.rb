# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class RezervAdapterTest < ActiveSupport::TestCase
      test "returns available slots from rezerv calendar response" do
        venue = VenueCatalog.find("pickle_village")
        search = Search.new(
          date: Date.new(2026, 6, 14),
          play_time: Time.zone.local(2026, 6, 14, 10, 0),
          play_time_end: Time.zone.local(2026, 6, 14, 16, 0)
        )

        stub_rezerv_request(venue)

        slots = RezervAdapter.new.fetch_slots(venue, search)

        assert slots.any? { |slot| slot.starts_at.hour == 6 && slot.ends_at.hour == 7 }
        assert_includes slots.map(&:court), "COURT 1"
        assert slots.all? { |slot| slot.ends_at > slot.starts_at }
      end

      private

      def stub_rezerv_request(venue)
        body = file_fixture("rezerv_pickle_village_2026-06-14.json").read
        stub_request(:get, /customer-api\.rezerv\.co\/v3\/appt-schedule\/timeslot_calendar/)
          .with(headers: { "Origin" => venue.config.fetch("origin") })
          .to_return(status: 200, body:)
      end

      def rezerv_url(venue)
        "https://customer-api.rezerv.co/v3/appt-schedule/timeslot_calendar?apptId=#{venue.config.fetch('appt_id')}&apptDate=2026-06-14&locationId=#{venue.config.fetch('location_id')}"
      end
    end
  end
end
