# frozen_string_literal: true

module Availability
  class SlotMatcher
    def self.matching_slots(search, slots)
      slots.select { |slot| covers?(search, slot) }
    end

    def self.covers?(search, slot)
      search.time_windows.any? do |starts_at, ends_at|
        if search.day_parts.any?
          slot.starts_at < ends_at && slot.ends_at > starts_at
        else
          slot.starts_at <= ends_at && slot.ends_at >= starts_at
        end
      end
    end
  end
end
