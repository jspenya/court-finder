# frozen_string_literal: true

module Availability
  Search = Data.define(:date, :play_time, :play_time_end) do
    def self.build(date:, play_time:, play_time_end:)
      raise InvalidSearch, "Select a start time" if play_time.blank?
      raise InvalidSearch, "Select an end time" if play_time_end.blank?

      parsed_date = Date.iso8601(date.to_s)
      start_hour, start_minute = parse_time_parts(play_time)
      end_hour, end_minute = parse_time_parts(play_time_end)
      play_at = Time.zone.local(parsed_date.year, parsed_date.month, parsed_date.day, start_hour, start_minute)
      play_end_at = Time.zone.local(parsed_date.year, parsed_date.month, parsed_date.day, end_hour, end_minute)

      validate!(parsed_date:, play_at:, play_end_at:)

      new(date: parsed_date, play_time: play_at, play_time_end: play_end_at)
    end

    def self.parse_time_parts(time)
      match = time.to_s.match(/\A(\d{1,2}):(\d{2})\z/)
      raise InvalidSearch, "Play time must use HH:MM format" unless match

      hour = match[1].to_i
      minute = match[2].to_i
      raise InvalidSearch, "Play time must be on the hour" unless minute.zero?
      raise InvalidSearch, "Play time is out of range" unless hour.in?(0..23)

      [ hour, minute ]
    end

    def self.validate!(parsed_date:, play_at:, play_end_at:)
      today = Time.zone.today
      raise InvalidSearch, "Date cannot be in the past" if parsed_date < today
      raise InvalidSearch, "End time must be after start time" if play_end_at <= play_at
      raise InvalidSearch, "Time window cannot be in the past" if play_end_at < Time.zone.now
    end
  end
end
