# frozen_string_literal: true

require "test_helper"

class SearchVenuesControllerTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }

  test "renders matching slots for a venue" do
    stub_rezerv

    get search_venue_path("pickle_village"), params: {
      date: "2026-06-14",
      play_time: "07:00",
      play_time_end: "16:00"
    }

    assert_response :success
    assert_select "turbo-frame#venue_pickle_village[data-status=available]"
    assert_select ".result--venue .result__title", text: "Pickle Village"
    assert_select ".result__slot-chip"
  end

  test "omits the venue card when no slots match" do
    stub_rezerv

    get search_venue_path("pickle_village"), params: {
      date: "2026-06-14",
      play_time: "10:00",
      play_time_end: "16:00"
    }

    assert_response :success
    assert_select "turbo-frame#venue_pickle_village[data-status=empty]"
    assert_select ".result--venue", count: 0
  end

  test "renders an error when the booking platform fails" do
    stub_request(:get, /customer-api\.rezerv\.co/).to_return(status: 503, body: "")

    get search_venue_path("pickle_village"), params: {
      date: "2026-06-14",
      play_time: "07:00",
      play_time_end: "16:00"
    }

    assert_response :success
    assert_select "turbo-frame#venue_pickle_village[data-status=error]"
    assert_select ".result--error", text: /Could not check availability/
  end

  test "rejects an unknown venue" do
    get search_venue_path("missing_venue"), params: {
      date: "2026-06-14",
      play_time: "07:00",
      play_time_end: "16:00"
    }

    assert_response :not_found
  end

  private

  def stub_rezerv
    venue = Availability::VenueCatalog.find("pickle_village")
    stub_request(:get, /customer-api\.rezerv\.co\/v3\/appt-schedule\/timeslot_calendar/)
      .with(headers: { "Origin" => venue.config.fetch("origin") })
      .to_return(status: 200, body: file_fixture("rezerv_pickle_village_2026-06-14.json").read)
  end
end
