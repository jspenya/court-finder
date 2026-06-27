# frozen_string_literal: true

require "test_helper"

module Availability
  class RunCheckTest < ActiveSupport::TestCase
    setup { Rails.cache.clear }

    test "returns matching venues sorted by closest slot start to play time" do
      search = Search.build(date: "2026-06-14", play_time: "07:00", play_time_end: "16:00")

      stub_all_venues

      outcome = RunCheck.call(search)

      assert outcome[:results].any? { |result| result.venue.id == "pickle_village" }
      assert outcome[:checked_at].present?
      assert_not outcome[:empty]
    end

    private

    def stub_all_venues
      VenueCatalog.all.each do |venue|
        if venue.rezerv?
          stub_request(:get, /customer-api\.rezerv\.co\/v3\/appt-schedule\/timeslot_calendar/)
            .with(headers: { "Origin" => venue.config.fetch("origin") })
            .to_return(status: 200, body: file_fixture("rezerv_pickle_village_2026-06-14.json").read)
        elsif venue.courtogo?
          stub_courtogo_requests(venue)
        else
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
      end
    end

    def rezerv_url(venue)
      "https://customer-api.rezerv.co/v3/appt-schedule/timeslot_calendar?apptId=#{venue.config.fetch('appt_id')}&apptDate=2026-06-14&locationId=#{venue.config.fetch('location_id')}"
    end

    def bookingdyno_page_url(venue)
      slug = venue.config.fetch("page_slug")
      service_id = CGI.escape(venue.config.fetch("service_id"))
      "https://bookingdyno.com/publicview/bookingdetails/#{slug}?id=#{service_id}"
    end

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
