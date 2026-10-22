# frozen_string_literal: true

require "test_helper"

module Availability
  module Adapters
    class QsportsAdapterTest < ActiveSupport::TestCase
      test "routes each QSports court and excludes unavailable slots" do
        %w[qsports_club_court_1 qsports_club_court_2].each do |id|
          venue = VenueCatalog.find(id)
          search = Search.build(date: "2026-06-14", play_time: "07:00", play_time_end: "10:00")
          stub_request(:get, "https://www.qsportscdo.com/api/availability")
            .with(query: { courtId: venue.config.fetch("court_id"), date: "2026-06-14" })
            .to_return(body: { courtName: venue.name, slots: [
              { hour: 7, available: true }, { hour: 8, available: false }
            ] }.to_json)

          result = CheckVenue.call(venue:, search:)

          assert_nil result.error
          assert_equal 1, result.slots.size
          assert_equal venue.name, result.slots.first.court
          assert_equal Time.zone.local(2026, 6, 14, 7), result.slots.first.starts_at
          assert_equal 1.hour, result.slots.first.ends_at - result.slots.first.starts_at
        end
      end
    end
  end
end
