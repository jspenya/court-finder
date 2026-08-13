# frozen_string_literal: true

require "test_helper"

module Availability
  class VenueCatalogTest < ActiveSupport::TestCase
    test "each venue has an address and google maps link" do
      VenueCatalog.all.each do |venue|
        assert venue.address.present?, "#{venue.name} is missing an address"
        assert_match %r{\Ahttps://www\.google\.com/maps/}, venue.maps_url, "#{venue.name} is missing a Google Maps link"
      end
    end

    test "pickle village is in macasandig" do
      venue = VenueCatalog.find("pickle_village")

      assert_equal "St. Ignatius St., Macasandig", venue.address
      assert_includes venue.maps_url, "query="
    end
  end
end
