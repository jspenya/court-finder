# frozen_string_literal: true

module Availability
  module Adapters
    class QsportsAdapter < BaseAdapter
      def fetch_slots(venue, search)
        query = URI.encode_www_form(courtId: venue.config.fetch("court_id"), date: search.date.iso8601)
        payload = get_json("https://www.qsportscdo.com/api/availability?#{query}")

        payload.fetch("slots").filter_map do |slot|
          next unless slot.fetch("available", false)

          starts_at = Time.zone.local(search.date.year, search.date.month, search.date.day, slot.fetch("hour"))
          Slot.new(starts_at:, ends_at: starts_at + 1.hour, court: payload.fetch("courtName"))
        end.sort_by(&:starts_at)
      end
    end
  end
end
