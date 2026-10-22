# frozen_string_literal: true

module Availability
  module Adapters
    class MatchpointAdapter < BaseAdapter
      BASE_URL = "https://matchpointsc.com"

      def fetch_slots(venue, search)
        html = get_text("#{BASE_URL}/")
        settings = html.match(/var dp_ajax\s*=\s*(\{.*?\});/)
        raise AdapterError, "Could not resolve Matchpoint booking settings" unless settings

        nonce = JSON.parse(settings[1]).fetch("nonce")
        payload = post_json(
          "#{BASE_URL}/wp-admin/admin-ajax.php",
          body: URI.encode_www_form(action: "dp_get_time_slots", nonce:, date: search.date.iso8601),
          headers: { "Content-Type" => "application/x-www-form-urlencoded" }
        )
        raise AdapterError, "Could not fetch Matchpoint availability" unless payload.fetch("success", false)

        payload.fetch("data").fetch("courts").flat_map do |court|
          court.fetch("slots").filter_map do |clock, slot|
            next unless slot.fetch("status") == "available"

            hour, minute = clock.split(":").map(&:to_i)
            starts_at = Time.zone.local(search.date.year, search.date.month, search.date.day, hour, minute)
            Slot.new(starts_at:, ends_at: starts_at + 1.hour, court: court.fetch("name"))
          end
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      end
    end
  end
end
