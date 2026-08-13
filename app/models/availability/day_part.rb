# frozen_string_literal: true

module Availability
  class DayPart
    PERIODS = [
      [ "Morning", 5...12 ],
      [ "Afternoon", 12...17 ]
    ].freeze

    def self.name_for(time)
      hour = time.hour
      PERIODS.each do |name, hours|
        return name if hours.cover?(hour)
      end

      "Evening"
    end

    def self.group(slots)
      grouped = slots.group_by { |slot| name_for(slot.starts_at) }

      [ "Morning", "Afternoon", "Evening" ].filter_map do |name|
        period_slots = grouped[name]
        next if period_slots.blank?

        [ name, period_slots.sort_by(&:starts_at) ]
      end
    end
  end
end
