# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class PickleplayAdapterTest < ActiveSupport::TestCase
      setup do
        @venue = VenueCatalog.find("the_playground")
        @search = Search.build(date: "2026-06-14", play_time: "08:00", play_time_end: "12:00")
        @url = "https://pickleplay-pro.onrender.com/courts-availability?date=2026-06-14"
      end

      test "venue check returns available slots across courts in Manila time" do
        stub_payload(success: true, courts: [
          { name: "Court 1", slots: [ slot("08:00", "09:00"), slot("09:00", "10:00", isAvailable: false) ] },
          { name: "Court 2", slots: [ slot("10:00", "11:00"), slot("11:00", "12:00", courtActive: false) ] }
        ])

        result = CheckVenue.call(venue: @venue, search: @search)

        assert_nil result.error
        assert_equal [ "Court 1", "Court 2" ], result.slots.map(&:court)
        assert_equal [ 8, 10 ], result.slots.map { |s| s.starts_at.hour }
        assert result.slots.all? { |s| s.starts_at.utc_offset == 8.hours && s.ends_at - s.starts_at == 1.hour }
      end

      test "midnight endpoints finish on the following day" do
        stub_payload(success: true, courts: [
          { name: "Court 1", slots: [ slot("23:00", "24:00") ] },
          { name: "Court 2", slots: [ slot("23:00", "00:00") ] }
        ])

        slots = PickleplayAdapter.new.fetch_slots(@venue, @search)

        assert_equal 2, slots.size
        assert slots.all? { |s| s.ends_at == Time.zone.local(2026, 6, 15) && s.ends_at - s.starts_at == 1.hour }
      end

      test "closed days return no availability" do
        stub_payload(success: true, isDayClosed: true, courts: [
          { name: "Court 1", slots: [ slot("08:00", "09:00") ] }
        ])

        assert_empty PickleplayAdapter.new.fetch_slots(@venue, @search)
      end

      test "failed and malformed responses produce venue errors" do
        [ { success: false }, { success: true }, "Maintenance" ].each do |payload|
          stub_payload(payload)
          result = CheckVenue.call(venue: @venue, search: @search)

          assert result.error.present?
          assert_empty result.slots
        end
      end

      test "http failures produce venue errors" do
        stub_request(:get, @url).to_return(status: 503)

        assert_equal "HTTP 503", CheckVenue.call(venue: @venue, search: @search).error
      end

      private

      def slot(start_time, end_time, **attributes)
        { startTime: start_time, endTime: end_time, isAvailable: true, courtActive: true }.merge(attributes)
      end

      def stub_payload(payload)
        stub_request(:get, @url).to_return(body: payload.is_a?(String) ? payload : payload.to_json)
      end
    end
  end
end
