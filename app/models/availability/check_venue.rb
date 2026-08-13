# frozen_string_literal: true

module Availability
  class CheckVenue
    TIMEOUT_SECONDS = Adapters::BaseAdapter::TIMEOUT_SECONDS
    CACHE_TTL = 2.minutes

    def self.call(venue:, search:)
      new(venue:, search:).call
    end

    def initialize(venue:, search:)
      @venue = venue
      @search = search
    end

    def call
      thread = Thread.new { check }
      unless thread.join(TIMEOUT_SECONDS)
        Rails.logger.warn("Availability check timed out venue=#{venue.id}")
        return failure_result("Timed out")
      end

      thread.value
    end

    private

    attr_reader :venue, :search

    def check
      payload = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        slots = adapter.fetch_slots(venue, search)
        fetched_at = Time.zone.now
        { slots:, fetched_at: }
      end
      matching = SlotMatcher.matching_slots(search, payload.fetch(:slots))
      checked_at = payload.fetch(:fetched_at)

      SearchResult.new(venue:, slots: matching, error: nil, checked_at:)
    rescue AdapterError => e
      Rails.logger.warn("Availability check failed venue=#{venue.id} error=#{e.message}")
      failure_result(e.message)
    end

    def cache_key
      [ "availability/slots", venue.id, search.date.iso8601 ]
    end

    def adapter
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

    def failure_result(message)
      SearchResult.new(venue:, slots: [], error: message, checked_at: Time.zone.now)
    end
  end
end
