# frozen_string_literal: true

require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  test "shows search form on root" do
    get root_path

    assert_response :success
    assert_select "h1.hero__title", text: /Open.*Courts/m
    assert_select "[data-controller='play-window-picker']"
    assert_select "form.search-form"
    assert_select ".play-window-picker button", text: "Update", count: 0
    assert_select ".play-window-picker button", text: "Cancel", count: 0
    assert_select ".play-window-picker__preset-name", text: "All Day"
    assert_select ".play-window-picker__preset-name", text: "Morning"
    assert_select ".play-window-picker__preset-name", text: "Afternoon"
    assert_select ".play-window-picker__preset-name", text: "Evening"
    assert_select ".play-window-picker__preset-range", text: "5 PM–12 AM"
  end

  test "restores and runs a shared availability search from the URL" do
    date = Time.zone.tomorrow.iso8601

    get root_path, params: {
      date: date,
      play_time: "07:00",
      play_time_end: "16:00"
    }

    assert_response :success
    assert_select "input[name='search[date]'][value='#{date}']"
    assert_select "input[name='search[play_time]'][value='07:00']"
    assert_select "input[name='search[play_time_end]'][value='16:00']"
    Availability::VenueCatalog.all.each do |venue|
      assert_select "turbo-frame#venue_#{venue.id}"
    end
  end

  test "rejects past time windows" do
    post search_path, params: {
      search: {
        date: Time.zone.today.iso8601,
        play_time: "08:00",
        play_time_end: "09:00"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".form__error", /past/i
  end

  test "returns turbo stream for invalid search" do
    post search_path,
      params: {
        search: {
          date: Time.zone.today.iso8601,
          play_time: "08:00",
          play_time_end: "09:00"
        }
      },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_includes response.body, 'turbo-stream action="replace" target="search-form"'
    assert_includes response.body, 'turbo-stream action="replace" target="search-loading"'
  end

  test "returns venue frames without waiting on booking platforms" do
    post search_path,
      params: {
        search: {
          date: "2026-06-14",
          play_time: "07:00",
          play_time_end: "16:00"
        }
      },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'turbo-stream action="update" target="results"'
    Availability::VenueCatalog.all.each do |venue|
      assert_includes response.body, %(id="venue_#{venue.id}")
      assert_includes response.body, search_venue_path(venue.id)
    end
  end
end
