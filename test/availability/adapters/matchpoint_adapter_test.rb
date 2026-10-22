# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class MatchpointAdapterTest < ActiveSupport::TestCase
      setup do
        @venue = VenueCatalog.find("matchpoint")
        @search = Search.build(date: "2026-06-14", play_time: "07:00", play_time_end: "12:00")
        stub_request(:get, "https://matchpointsc.com/")
          .to_return(body: '<script>var dp_ajax = {"nonce":"fresh-nonce"};</script>')
      end

      test "uses current nonce and returns only available court slots" do
        stub_slots(success: true, data: { courts: [
          { name: "Court 1", slots: { "08:00" => { status: "available" }, "09:00" => { status: "booked" } } },
          { name: "Court 2", slots: { "08:00" => { status: "unavailable" }, "10:00" => { status: "available" } } }
        ] })

        result = CheckVenue.call(venue: @venue, search: @search)

        assert_nil result.error
        assert_equal [ "Court 1", "Court 2" ], result.slots.map(&:court)
        assert_equal [ 8, 10 ], result.slots.map { |slot| slot.starts_at.hour }
        assert result.slots.all? { |slot| slot.starts_at.utc_offset == 8.hours && slot.ends_at - slot.starts_at == 1.hour }
      end

      test "failed availability is an error rather than an empty result" do
        stub_slots(success: false, data: { message: "Unavailable" })
        result = CheckVenue.call(venue: @venue, search: @search)
        assert result.error.present?
      end

      test "missing booking settings returns an error" do
        stub_request(:get, "https://matchpointsc.com/").to_return(body: "Maintenance")
        result = CheckVenue.call(venue: @venue, search: @search)
        assert result.error.present?
      end

      private

      def stub_slots(payload)
        stub_request(:post, "https://matchpointsc.com/wp-admin/admin-ajax.php")
          .with(body: { action: "dp_get_time_slots", nonce: "fresh-nonce", date: "2026-06-14" })
          .to_return(body: payload.to_json)
      end
    end
  end
end
