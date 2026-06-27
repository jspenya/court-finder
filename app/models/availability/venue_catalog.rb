# frozen_string_literal: true

module Availability
  class VenueCatalog
    Venue = Data.define(:id, :name, :platform, :booking_url, :config) do
      def rezerv?
        platform == "rezerv"
      end

      def bookingdyno?
        platform == "bookingdyno"
      end

      def courtogo?
        platform == "courtogo"
      end
    end

    def self.all
      if Rails.application.config.cache_classes
        @all ||= load_venues
      else
        load_venues
      end
    end

    def self.find(id)
      all.find { |venue| venue.id == id }
    end

    def self.load_venues
      raw = YAML.load_file(Rails.root.join("config/venues.yml"))
      raw.fetch("venues").map do |id, attrs|
        Venue.new(
          id: id.to_s,
          name: attrs.fetch("name"),
          platform: attrs.fetch("platform"),
          booking_url: attrs.fetch("booking_url"),
          config: attrs
        )
      end
    end

    private_class_method :load_venues
  end
end
