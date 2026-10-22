# frozen_string_literal: true

module Availability
  module Adapters
    class KhourtAdapter < BaseAdapter
      BASE_URL = "https://www.khourt.com/api/venues"

      def fetch_slots(venue, search)
        slug = venue.config.fetch("slug")
        venue.config.fetch("courts").flat_map do |court|
          query = URI.encode_www_form(resourceId: court.fetch("id"), date: search.date.iso8601)
          payload = get_json("#{BASE_URL}/#{slug}/public-availability?#{query}")
          raise AdapterError, "Could not fetch Khourt availability" if payload["error"]
          next [] if payload["closed"]

          payload.fetch("slots").filter_map do |slot|
            next unless slot.fetch("status") == "available"

            starts_at = Time.iso8601(slot.fetch("startIso")).in_time_zone
            ends_at = Time.iso8601(slot.fetch("endIso")).in_time_zone
            raise AdapterError, "Invalid Khourt slot duration" unless ends_at > starts_at

            Slot.new(starts_at:, ends_at:, court: court.fetch("name"))
          end
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      rescue JSON::ParserError, KeyError, TypeError, ArgumentError => e
        raise AdapterError, "Invalid Khourt availability response: #{e.message}"
      end
    end
  end
end
