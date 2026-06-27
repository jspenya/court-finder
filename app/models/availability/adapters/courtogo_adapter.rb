# frozen_string_literal: true

require "set"

module Availability
  module Adapters
    class CourtogoAdapter < BaseAdapter
      SUPABASE_URL = "https://nmhfoxlndbrwtkvnpxaj.supabase.co"
      SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." \
        "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5taGZveGxuZGJyd3Rrdm5weGFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyMDgwNzcsImV4cCI6MjA4Njc4NDA3N30." \
        "PSRo3sPnbuZTnDQHBL3uOLnhrVCBGSIXzIrxzz97wPs"
      BOOKING_STATUSES = %w[pending payment_pending confirmed completed].freeze

      def fetch_slots(venue, search)
        venue_id = venue.config.fetch("venue_id")
        courts = fetch_courts(venue_id)
        operating_hours = fetch_operating_hours(venue_id)
        return [] if operating_hours.fetch("closed", false)

        slot_times = hourly_slot_times(operating_hours)
        booked = booked_slots(courts, search.date, operating_hours)
        blocked = blocked_slots(venue_id, courts, search.date, operating_hours, slot_times)

        courts.flat_map do |court|
          slot_times.filter_map do |slot_time|
            next if booked.include?(booked_key(court.fetch("id"), slot_time))
            next if blocked.include?(blocked_key(court.fetch("id"), slot_time))

            starts_at = time_on(search.date, slot_time)
            ends_at = starts_at + 1.hour
            Slot.new(starts_at:, ends_at:, court: court.fetch("name"))
          end
        end.sort_by { |slot| [ slot.court, slot.starts_at ] }
      end

      private

      def fetch_courts(venue_id)
        supabase_get(
          "courts",
          {
            venue_id: "eq.#{venue_id}",
            active: "eq.true",
            select: "id,name,court_number",
            order: "court_number"
          }
        )
      end

      def fetch_operating_hours(venue_id)
        rows = supabase_get(
          "venues",
          {
            id: "eq.#{venue_id}",
            select: "operating_hours"
          }
        )
        rows.first.fetch("operating_hours")
      end

      def booked_slots(courts, date, operating_hours)
        court_ids = courts.map { |court| court.fetch("id") }
        booking_dates = session_dates(date, operating_hours)
        rows = supabase_get(
          "booking_slots",
          {
            select: "court_id,time_slot,booking_date,bookings!inner(status)",
            court_id: "in.(#{court_ids.join(',')})",
            booking_date: "in.(#{booking_dates.join(',')})",
            "bookings.status": "in.(#{BOOKING_STATUSES.join(',')})"
          }
        )

        closing_minutes = closing_minutes(operating_hours)
        next_date = booking_dates[1]

        rows.filter_map do |row|
          minutes = time_to_minutes(row.fetch("time_slot"))
          booking_date = Date.iso8601(row.fetch("booking_date"))

          next if skip_booking_row?(booking_date, date, next_date, minutes, closing_minutes, operating_hours)

          booked_key(row.fetch("court_id"), minutes_to_clock(minutes))
        end.to_set
      end

      def blocked_slots(venue_id, courts, date, operating_hours, slot_times)
        booking_dates = session_dates(date, operating_hours)
        blocked_times = booking_dates.flat_map do |booking_date|
          blocked_times_for_date(venue_id, booking_date)
        end

        courts.flat_map do |court|
          slot_times.filter_map do |slot_time|
            minutes = time_to_minutes(slot_time)
            next unless blocked_at?(blocked_times, court.fetch("id"), date, minutes, operating_hours)

            blocked_key(court.fetch("id"), slot_time)
          end
        end.to_set
      end

      def blocked_times_for_date(venue_id, date)
        payload = get_json(
          "https://www.courtogo.com/api/venues/#{venue_id}/blocked-times?date=#{date.iso8601}"
        )
        payload.fetch("blockedTimes", [])
      end

      def blocked_at?(blocked_times, court_id, session_date, minutes, operating_hours)
        blocked_times.any? do |blocked|
          applies_to_court?(blocked, court_id) &&
            applies_to_date?(blocked, session_date, minutes, operating_hours) &&
            covers_minute?(blocked, minutes)
        end
      end

      def applies_to_court?(blocked, court_id)
        blocked_court_id = blocked["court_id"]
        blocked_court_id.nil? || blocked_court_id == court_id
      end

      def applies_to_date?(blocked, session_date, minutes, operating_hours)
        case blocked.fetch("block_type")
        when "date"
          blocked.fetch("blocked_date") == slot_booking_date(session_date, minutes, operating_hours).iso8601
        when "weekly"
          day = session_date.wday.to_s
          blocked.fetch("days_of_week", []).include?(day)
        else
          false
        end
      end

      def covers_minute?(blocked, minutes)
        start_minutes = time_to_minutes(blocked.fetch("start_time"))
        end_minutes = time_to_minutes(blocked.fetch("end_time"))
        return minutes >= start_minutes if end_minutes.zero?

        if end_minutes > start_minutes
          minutes >= start_minutes && minutes < end_minutes
        else
          minutes >= start_minutes || minutes < end_minutes
        end
      end

      def skip_booking_row?(booking_date, session_date, next_date, minutes, closing_minutes, operating_hours)
        return false unless operating_hours.fetch("is_overnight", false)
        return false if closing_minutes.zero?

        if booking_date == session_date && minutes < closing_minutes
          true
        elsif next_date && booking_date == next_date && minutes >= closing_minutes
          true
        else
          false
        end
      end

      def hourly_slot_times(operating_hours)
        start_minutes = time_to_minutes(operating_hours.fetch("start"))
        end_minutes = time_to_minutes(operating_hours.fetch("end"))

        if start_minutes < end_minutes
          slot_count = (end_minutes - start_minutes) / 60
          slot_count.times.map { |index| minutes_to_clock(start_minutes + (index * 60)) }
        elsif start_minutes > end_minutes
          slot_count = ((1440 - start_minutes) + end_minutes) / 60
          slot_count.times.map { |index| minutes_to_clock((start_minutes + (index * 60)) % 1440) }
        else
          24.times.map { |index| minutes_to_clock((start_minutes + (index * 60)) % 1440) }
        end
      end

      def session_dates(date, operating_hours)
        dates = [ date ]
        dates << date + 1 if operating_hours.fetch("is_overnight", false)
        dates
      end

      def slot_booking_date(session_date, minutes, operating_hours)
        return session_date unless operating_hours.fetch("is_overnight", false)

        closing = closing_minutes(operating_hours)
        opening = time_to_minutes(operating_hours.fetch("start"))
        return session_date if closing.zero? || closing >= opening
        return session_date + 1 if minutes < closing

        session_date
      end

      def closing_minutes(operating_hours)
        time_to_minutes(operating_hours.fetch("end"))
      end

      def supabase_get(table, params)
        query = URI.encode_www_form(params)
        get_json("#{SUPABASE_URL}/rest/v1/#{table}?#{query}", headers: supabase_headers)
      end

      def supabase_headers
        {
          "apikey" => SUPABASE_ANON_KEY,
          "Authorization" => "Bearer #{SUPABASE_ANON_KEY}",
          "Accept" => "application/json",
          "Accept-Encoding" => "identity"
        }
      end

      def booked_key(court_id, slot_time)
        "#{court_id}:#{slot_time}"
      end

      def blocked_key(court_id, slot_time)
        booked_key(court_id, slot_time)
      end

      def time_to_minutes(clock_time)
        hour, minute, = clock_time.to_s.split(":").map(&:to_i)
        (hour * 60) + minute
      end

      def minutes_to_clock(minutes)
        hour = minutes / 60
        minute = minutes % 60
        format("%02d:%02d:00", hour, minute)
      end

      def time_on(date, clock_time)
        hour, minute, second = clock_time.split(":").map(&:to_i)
        Time.zone.local(date.year, date.month, date.day, hour, minute, second)
      end
    end
  end
end
