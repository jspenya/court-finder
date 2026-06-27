# frozen_string_literal: true

class SearchesController < ApplicationController
  def new
    @search_defaults = default_search_params
  end

  def create
    @search = Availability::Search.build(
      date: search_params[:date],
      play_time: search_params[:play_time],
      play_time_end: search_params[:play_time_end]
    )
    outcome = Availability::RunCheck.call(@search)
    @results = outcome[:results]
    @checked_at = outcome[:checked_at]
    @empty = outcome[:empty]
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
    params.expect(search: [ :date, :play_time, :play_time_end ])
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
