# frozen_string_literal: true

module Availability
  class SlotMatcher
    def self.matching_slots(search, slots)
      slots.select { |slot| covers?(search, slot) }
    end

    def self.covers?(search, slot)
      slot.starts_at <= search.play_time_end && slot.ends_at >= search.play_time
    end
  end
end
