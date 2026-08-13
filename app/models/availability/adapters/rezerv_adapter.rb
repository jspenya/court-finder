# frozen_string_literal: true

module Availability
  module Adapters
    class RezervAdapter < BaseAdapter
      API_URL = "https://customer-api.rezerv.co/v3/appt-schedule/timeslot_calendar"

      def fetch_slots(venue, search)
        payload = get_json(
          calendar_url(venue, search),
          headers: { "Origin" => venue.config.fetch("origin") }
        )

        parse_slots(payload, search.date)
      end

      private

      def calendar_url(venue, search)
        params = {
          apptId: venue.config.fetch("appt_id"),
          locationId: venue.config.fetch("location_id"),
          apptDate: search.date.iso8601
        }
        "#{API_URL}?#{URI.encode_www_form(params)}"
      end

      def parse_slots(payload, date)
        resource_slots = payload.dig("data", "resourceSlots") || []

        resource_slots.flat_map do |court|
          court_name = court.fetch("name")
          court.fetch("slots", []).filter_map do |entry|
            next unless entry["status"] == "Available"

            starts_at = time_on(date, entry.fetch("startTime"))
            ends_at = time_on(date, entry.fetch("endTime"))
            Slot.new(starts_at:, ends_at:, court: court_name)
          end
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      end

      def time_on(date, clock_time)
        days, time_part = split_timespan(clock_time)
        hour, minute, second = time_part.split(":").map(&:to_i)
        Time.zone.local(date.year, date.month, date.day, hour, minute, second) + days.days
      end

      def split_timespan(clock_time)
        day_part, time_part = clock_time.split(".", 2)
        return [ 0, clock_time ] if time_part.nil?

        [ day_part.to_i, time_part ]
      end
    end
  end
end
