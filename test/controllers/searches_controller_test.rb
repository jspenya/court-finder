# frozen_string_literal: true

require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  test "shows search form on root" do
    get root_path

    assert_response :success
    assert_select "h1.hero__title", text: /Open.*Courts/m
    assert_select "[data-controller='play-window-picker']"
    assert_select "form.search-form"
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
end
