# frozen_string_literal: true

module Availability
  module Adapters
    class PickleplayAdapter < BaseAdapter
      BASE_URL = "https://pickleplay-pro.onrender.com"

      def fetch_slots(venue, search)
        payload = get_json("#{BASE_URL}/courts-availability?date=#{search.date.iso8601}")
        raise AdapterError, "Could not fetch Playground availability" unless payload.fetch("success", false)
        return [] if payload["isDayClosed"]

        payload.fetch("courts").flat_map do |court|
          court.fetch("slots").filter_map do |slot|
            next unless slot.fetch("isAvailable", false) && slot.fetch("courtActive", false)

            starts_at = time_on(search.date, slot.fetch("startTime"))
            ends_at = time_on(search.date, slot.fetch("endTime"))
            ends_at += 1.day if ends_at <= starts_at

            Slot.new(starts_at:, ends_at:, court: court.fetch("name"))
          end
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      rescue JSON::ParserError, KeyError, TypeError => e
        raise AdapterError, "Invalid Playground availability response: #{e.message}"
      end

      private

      def time_on(date, clock)
        hour, minute = clock.split(":").map(&:to_i)
        date.beginning_of_day + hour.hours + minute.minutes
      end
    end
  end
end
