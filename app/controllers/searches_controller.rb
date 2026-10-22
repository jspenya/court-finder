# frozen_string_literal: true

class SearchesController < ApplicationController
  def new
    shared_params = shared_search_params.to_h.symbolize_keys
    @search_defaults = default_search_params.merge(shared_params)
    return unless [ :date, :play_time, :play_time_end ].all? { |key| shared_params[key].present? }

    @search = Availability::Search.build(
      date: shared_params[:date],
      play_time: shared_params[:play_time],
      play_time_end: shared_params[:play_time_end],
      day_parts: shared_params[:day_parts]
    )
  rescue Availability::InvalidSearch => e
    @search_error = e.message
  end

  def create
    @search = Availability::Search.build(
      date: search_params[:date],
      play_time: search_params[:play_time],
      play_time_end: search_params[:play_time_end],
      day_parts: search_params[:day_parts]
    )
    @search_defaults = search_params
    respond_to do |format|
      format.turbo_stream
      format.html { render :new }
    end
  rescue Availability::InvalidSearch => e
    @search_error = e.message
    @search_defaults = search_params
    respond_to do |format|
      format.turbo_stream { render :invalid_search, status: :unprocessable_entity }
      format.html { render :new, status: :unprocessable_entity }
    end
  end

  private

  def search_params
    params.expect(search: [ :date, :play_time, :play_time_end, :day_parts ])
  end

  def shared_search_params
    params.permit(:date, :play_time, :play_time_end, :day_parts)
  end

  def default_search_params
    now = Time.zone.now
    if now.min.zero?
      hour = now.hour
      date = Time.zone.today
    else
      hour = now.hour + 1
      date = Time.zone.today
    end

    if hour > 23
      hour = 0
      date = Time.zone.tomorrow
    end

    end_hour = hour + 3
    if end_hour > 23
      end_hour = 23
    end

    {
      date: date.iso8601,
      play_time: format("%02d:00", hour),
      play_time_end: format("%02d:00", end_hour)
    }
  end
end
