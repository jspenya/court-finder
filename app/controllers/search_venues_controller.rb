# frozen_string_literal: true

class SearchVenuesController < ApplicationController
  helper SearchesHelper
  layout false

  def show
    venue = Availability::VenueCatalog.find(params[:id])
    return head :not_found unless venue

    @search = Availability::Search.build(
      date: params[:date],
      play_time: params[:play_time],
      play_time_end: params[:play_time_end]
    )
    @result = Availability::CheckVenue.call(venue:, search: @search)
  rescue Availability::InvalidSearch
    head :unprocessable_entity
  end
end
