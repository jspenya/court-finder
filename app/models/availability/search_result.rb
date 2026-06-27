# frozen_string_literal: true

module Availability
  SearchResult = Data.define(:venue, :slots, :error, :checked_at) do
    def success?
      error.nil?
    end

    def earliest_slot_start
      slots.min_by(&:starts_at)&.starts_at
    end

    def slots_by_court
      slots.group_by(&:court).sort_by { |court, _| court.to_s }
    end
  end
end
