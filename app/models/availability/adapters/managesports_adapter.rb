# frozen_string_literal: true

module Availability
  module Adapters
    class ManagesportsAdapter < BaseAdapter
      API_BASE = "https://api.managesports.app/api/public"

      def fetch_slots(venue, search)
        slug = venue.config.fetch("slug")
        payload = get_json(
          "#{API_BASE}/#{slug}/availability?date=#{search.date.iso8601}",
          headers: { "Accept" => "application/json" }
        )
        return [] if payload.fetch("is_closed", false)

        payload.fetch("courts", []).flat_map do |court|
          duration = court.fetch("slot_duration", 60).to_i
          court.fetch("slots", []).filter_map do |slot|
            next unless slot.fetch("available", false)
            next if slot.fetch("is_past", false) || slot.fetch("is_pending", false)

            starts_at = time_on(search.date, slot.fetch("time"))
            ends_at = starts_at + (duration * 60)
            Slot.new(starts_at:, ends_at:, court: court.fetch("name"))
          end
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      end

      private

      def time_on(date, clock_time)
        parsed = Time.strptime(clock_time, "%I:%M %p")
        Time.zone.local(date.year, date.month, date.day, parsed.hour, parsed.min)
      end
    end
  end
end
