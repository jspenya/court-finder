# frozen_string_literal: true

module Availability
  module Adapters
    class KourtsuiteAdapter < BaseAdapter
      BASE_URL = "https://kourtsuite-607325852099.asia-southeast1.run.app"

      def fetch_slots(venue, search)
        code = venue.config.fetch("tenant_code")
        payload = get_json("#{BASE_URL}/tenants/#{code}/availability?date=#{search.date.iso8601}")

        payload.fetch("data").fetch("slots").filter_map do |slot|
          next unless slot.fetch("available", false)

          start_clock, end_clock = slot.fetch("timeSlot").split("-")
          starts_at = time_on(search.date, start_clock)
          ends_at = time_on(search.date, end_clock)
          ends_at += 1.day if ends_at <= starts_at

          Slot.new(starts_at:, ends_at:, court: "Court #{slot.fetch('court')}")
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      end

      private

      def time_on(date, clock)
        hour, minute = clock.split(":").map(&:to_i)
        Time.zone.local(date.year, date.month, date.day, hour, minute)
      end
    end
  end
end
