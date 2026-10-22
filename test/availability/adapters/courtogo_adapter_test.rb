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

      test "excludes weekly blocked slots when days_of_week are integers" do
        venue = VenueCatalog.find("pickle_point")
        search = Search.new(
          date: Date.new(2026, 8, 13),
          play_time: Time.zone.local(2026, 8, 13, 20, 0),
          play_time_end: Time.zone.local(2026, 8, 13, 21, 0)
        )

        stub_courtogo_requests(
          venue,
          bookings: "[]",
          blocked_times: file_fixture("courtogo_pickle_point_weekly_blocked_times.json").read
        )

        slots = CourtogoAdapter.new.fetch_slots(venue, search)

        assert_not slots.any? { |slot| slot.starts_at.hour == 20 && slot.court == "Court 1" }
        assert slots.any? { |slot| slot.starts_at.hour == 8 && slot.court == "Court 1" }
        assert slots.any? { |slot| slot.starts_at.hour == 20 && slot.court == "Court 2" }
      end

      test "uses Frontyard weekday overrides including closed days" do
        venue = VenueCatalog.find("frontyard")
        search = Search.build(date: "2026-06-14", play_time: "21:00", play_time_end: "23:00")
        stub_courtogo_requests(venue, bookings: "[]", blocked_times: '{"blockedTimes":[]}')
        hours = { start: "06:00", end: "22:00", day_overrides: { "0" => { end: "23:00" } } }
        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/venues})
          .to_return(body: [ { operating_hours: hours } ].to_json)

        slots = CourtogoAdapter.new.fetch_slots(venue, search)
        assert slots.any? { |slot| slot.starts_at.hour == 22 }
        assert_not slots.any? { |slot| slot.starts_at.hour == 23 }

        hours[:day_overrides]["0"] = { closed: true }
        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/venues})
          .to_return(body: [ { operating_hours: hours } ].to_json)
        assert_empty CourtogoAdapter.new.fetch_slots(venue, search)
      end

      test "excludes Dink District daily blocks and named tournament reservations" do
        venue = VenueCatalog.find("dink_district")
        fixture = JSON.parse(file_fixture("courtogo_dink_district.json").read)
        stub_courtogo_requests(venue, bookings: "[]", blocked_times: fixture.fetch("blocked_times").to_json)
        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/courts})
          .to_return(body: fixture.fetch("courts").to_json)
        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/venues})
          .to_return(body: fixture.fetch("venue").to_json)
        search = Search.build(date: "2026-10-24", play_time: "08:00", play_time_end: "09:00")

        slots = CourtogoAdapter.new.fetch_slots(venue, search)

        assert_not slots.any? { |slot| slot.court == "Court 9" }, "Daily blocked Court 9 must never appear available"
        assert_equal (0...8).to_a, slots.select { |slot| slot.court == "Court 1" }.map { |slot| slot.starts_at.hour }
        assert_equal 24, slots.count { |slot| slot.court == "Training Room 1" }
      end

      test "daily blocks respect inclusive recurrence dates and allow unnamed venue-wide blocks" do
        venue = VenueCatalog.find("pickle_point")
        block = {
          court_id: nil, block_type: "daily", reason: nil,
          start_time: "12:00:00", end_time: "14:00:00",
          recurrence_start_date: "2026-10-23", recurrence_end_date: "2026-10-25"
        }
        stub_courtogo_requests(venue, bookings: "[]", blocked_times: { blockedTimes: [ block ] }.to_json)

        (22..26).each do |day|
          search = Search.build(date: "2026-10-#{day}", play_time: "12:00", play_time_end: "14:00")
          slots = CourtogoAdapter.new.fetch_slots(venue, search)

          assert_equal !day.between?(23, 25), slots.any? { |slot| slot.starts_at.hour == 12 }, "October #{day}"
          assert slots.any? { |slot| slot.starts_at.hour == 14 }
        end

        block[:recurrence_start_date] = nil
        block[:recurrence_end_date] = nil
        stub_courtogo_requests(venue, bookings: "[]", blocked_times: { blockedTimes: [ block ] }.to_json)
        search = Search.build(date: "2026-10-26", play_time: "12:00", play_time_end: "14:00")
        assert_not CourtogoAdapter.new.fetch_slots(venue, search).any? { |slot| slot.starts_at.hour == 12 }
      end

      private

      def stub_courtogo_requests(venue, bookings: nil, blocked_times: nil)
        venue_id = venue.config.fetch("venue_id")

        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/courts})
          .to_return(status: 200, body: file_fixture("courtogo_pickle_point_courts.json").read)

        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/venues})
          .to_return(status: 200, body: file_fixture("courtogo_pickle_point_venue.json").read)

        stub_request(:get, %r{nmhfoxlndbrwtkvnpxaj\.supabase\.co/rest/v1/booking_slots})
          .to_return(
            status: 200,
            body: bookings || file_fixture("courtogo_pickle_point_bookings.json").read
          )

        stub_request(:get, %r{www\.courtogo\.com/api/venues/#{venue_id}/blocked-times})
          .to_return(
            status: 200,
            body: blocked_times || file_fixture("courtogo_pickle_point_blocked_times.json").read
          )
      end
    end
  end
end
