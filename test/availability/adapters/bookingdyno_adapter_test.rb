# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class BookingdynoAdapterTest < ActiveSupport::TestCase
      setup { Rails.cache.clear }

      test "returns available hourly slots for a date" do
        venue = VenueCatalog.find("paddle_play")
        search = Search.new(
          date: Date.new(2026, 6, 14),
          play_time: Time.zone.local(2026, 6, 14, 10, 0),
          play_time_end: Time.zone.local(2026, 6, 14, 16, 0)
        )

        stub_bookingdyno_requests(venue)

        slots = BookingdynoAdapter.new.fetch_slots(venue, search)

        assert_includes slots.map(&:starts_at).map(&:hour), 8
        assert_includes slots.map(&:court), "UNO"
        assert_not slots.any? { |slot| slot.starts_at.hour == 10 }
      end

      private

      def stub_bookingdyno_requests(venue)
        action_id = "400c83e2a02b6f777cca206a800c69c7647292386a"
        chunk_path = "/_next/static/chunks/abc123def456.js"

        stub_request(:post, "https://bookingdyno.com/api/public/requestToken")
          .to_return(status: 200, body: { token: "visitor-token" }.to_json)

        stub_request(:get, bookingdyno_page_url(venue))
          .to_return(status: 200, body: %(<script src="#{chunk_path}"></script>))

        stub_request(:get, "https://bookingdyno.com#{chunk_path}")
          .to_return(
            status: 200,
            body: "createServerReference)(\"#{action_id}\",r.callServer,void 0,r.findSourceMapURL,\"getBookingDetailsRecords\")"
          )

        action_body = JSON.generate(JSON.parse(file_fixture("bookingdyno_paddle_play.json").read))
        stub_request(:post, bookingdyno_page_url(venue))
          .to_return(status: 200, body: "0:{}\n1:#{action_body}")
      end

      def bookingdyno_page_url(venue)
        slug = venue.config.fetch("page_slug")
        service_id = CGI.escape(venue.config.fetch("service_id"))
        "https://bookingdyno.com/publicview/bookingdetails/#{slug}?id=#{service_id}"
      end
    end
  end
end
