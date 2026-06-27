# frozen_string_literal: true

module Availability
  class RunCheck
    TIMEOUT_SECONDS = Adapters::BaseAdapter::TIMEOUT_SECONDS

    def self.call(search)
      new(search).call
    end

    def initialize(search)
      @search = search
    end

    def call
      checked_at = Time.zone.now
      outcomes = VenueCatalog.all.map { |venue| check_with_timeout(venue, checked_at) }

      available = outcomes.select { |outcome| outcome.is_a?(SearchResult) && outcome.slots.any? }
      failures = outcomes.select { |outcome| outcome.is_a?(SearchResult) && outcome.error }
      empty = outcomes.all?(:no_match)

      {
        results: sort_available(available) + failures.sort_by { |result| result.venue.name },
        checked_at:,
        empty:
      }
    end

    private

    attr_reader :search

    def check_with_timeout(venue, checked_at)
      thread = Thread.new { check_venue(venue, checked_at) }
      return failure_result(venue, "Timed out", checked_at) unless thread.join(TIMEOUT_SECONDS)

      thread.value
    end

    def check_venue(venue, checked_at)
      slots = adapter_for(venue).fetch_slots(venue, search)
      matching = SlotMatcher.matching_slots(search, slots)
      return :no_match if matching.empty?

      SearchResult.new(venue:, slots: matching, error: nil, checked_at:)
    rescue AdapterError => e
      failure_result(venue, e.message, checked_at)
    end

    def adapter_for(venue)
      if venue.rezerv?
        Adapters::RezervAdapter.new
      elsif venue.bookingdyno?
        Adapters::BookingdynoAdapter.new
      elsif venue.courtogo?
        Adapters::CourtogoAdapter.new
      else
        raise AdapterError, "Unknown platform for #{venue.name}"
      end
    end

    def failure_result(venue, message, checked_at)
      SearchResult.new(venue:, slots: [], error: message, checked_at:)
    end

    def sort_available(results)
      results.sort_by { |result| distance_from_play_time(result) }
    end

    def distance_from_play_time(result)
      earliest = result.earliest_slot_start
      return Float::INFINITY unless earliest

      (earliest - search.play_time).abs
    end
  end
end
