# frozen_string_literal: true

module Availability
  module Adapters
    class BookingdynoAdapter < BaseAdapter
      TOKEN_URL = "https://bookingdyno.com/api/public/requestToken"
      BASE_URL = "https://bookingdyno.com"
      BOOKING_DETAILS_ACTION = "getBookingDetailsRecords"
      BOOKING_DETAILS_ACTION_PATTERN =
        /createServerReference\)\("([0-9a-f]{40,64})"[^)]*findSourceMapURL,"#{BOOKING_DETAILS_ACTION}"/
      CHUNK_PATH_PATTERN = %r{/_next/static/chunks/[a-f0-9]+\.js}

      def fetch_slots(venue, search)
        token = visitor_token
        record = booking_details_record(venue, token)
        day_name = search.date.strftime("%A")
        inventory_ids = venue.config.fetch("inventory_ids")
        court_names = inventory_names(record)

        available_times = parse_json_field(record["availableTimes"])
        blocked_labels = record.dig("blockedTimeMap", search.date.iso8601) || []
        unavailable_labels = record.dig("unavailableTimeMap", search.date.iso8601) || []
        unavailable_by_label = record.dig("unavailableInventoryByDateTime", search.date.iso8601) || {}

        available_times.flat_map do |entry|
          label = entry["label"]
          next [] unless day_applies?(entry, day_name)
          next [] if blocked_labels.include?(label)
          next [] if unavailable_labels.include?(label)

          blocked_ids = unavailable_by_label[label] || []
          starts_at = time_on(search.date, entry.fetch("timeFrom"))
          ends_at = time_on(search.date, entry.fetch("timeTo"))

          inventory_ids.filter_map do |inventory_id|
            next if blocked_ids.include?(inventory_id)

            Slot.new(starts_at:, ends_at:, court: court_names[inventory_id])
          end
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      end

      private

      def visitor_token
        payload = post_json(TOKEN_URL, body: "{}", headers: json_headers)
        payload.fetch("token")
      end

      def booking_details_record(venue, token)
        body = post_text(
          page_url(venue),
          body: booking_details_body(venue),
          headers: server_action_headers(venue, token, booking_details_action(venue))
        )

        parse_action_response(body).fetch("data").first
      end

      def booking_details_action(venue)
        Rails.cache.fetch(booking_details_action_cache_key(venue), expires_in: 1.hour) do
          resolve_booking_details_action(venue)
        end
      end

      def resolve_booking_details_action(venue)
        html = get_text(page_url(venue))
        html.scan(CHUNK_PATH_PATTERN).uniq.each do |path|
          js = get_text("#{BASE_URL}#{path}")
          match = js.match(BOOKING_DETAILS_ACTION_PATTERN)
          return match[1] if match
        end

        raise AdapterError, "Could not resolve #{BOOKING_DETAILS_ACTION} action"
      end

      def booking_details_action_cache_key(venue)
        "availability/bookingdyno/#{venue.id}/booking_details_action"
      end

      def page_url(venue)
        slug = venue.config.fetch("page_slug")
        service_id = CGI.escape(venue.config.fetch("service_id"))
        "#{BASE_URL}/publicview/bookingdetails/#{slug}?id=#{service_id}"
      end

      def booking_details_body(venue)
        service_id = venue.config.fetch("service_id")
        JSON.generate([ { "serviceId" => service_id, "type" => "customer" } ])
      end

      def server_action_headers(venue, token, action)
        json_headers.merge(
          "Accept" => "text/x-component",
          "Content-Type" => "text/plain;charset=UTF-8",
          "Authorization" => "Bearer #{token}",
          "next-action" => action
        )
      end

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def parse_action_response(body)
        payload_line = body.lines.find { |line| line.start_with?("1:") }
        raise AdapterError, "Missing action response" unless payload_line

        JSON.parse(payload_line.delete_prefix("1:").strip)
      end

      def parse_json_field(value)
        return value if value.is_a?(Array)

        JSON.parse(value || "[]")
      end

      def day_applies?(entry, day_name)
        days = entry.fetch("appliedToDays", "").split(",").map(&:strip)
        days.empty? || days.include?(day_name)
      end

      def inventory_names(record)
        record.fetch("inventoryRooms", []).to_h { |room| [ room.fetch("inventoryId"), room.fetch("name") ] }
      end

      def time_on(date, clock_time)
        hour, minute, second = clock_time.split(":").map(&:to_i)
        Time.zone.local(date.year, date.month, date.day, hour, minute, second)
      end
    end
  end
end
