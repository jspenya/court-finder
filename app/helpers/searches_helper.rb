# frozen_string_literal: true

module SearchesHelper
  PLAY_WINDOW_PRESETS = [
    { name: "All Day", start: "00:00", end: "00:00", range: "Any time" },
    { name: "Morning", start: "08:00", end: "12:00", range: "8 AM–12 PM" },
    { name: "Afternoon", start: "12:00", end: "17:00", range: "12–5 PM" },
    { name: "Evening", start: "17:00", end: "00:00", range: "5 PM–12 AM" }
  ].freeze

  def format_checked_at(time)
    time.strftime("%-I:%M %p")
  end

  def format_slot_time(slot)
    "#{slot.starts_at.strftime('%-I:%M %p')} – #{slot.ends_at.strftime('%-I:%M %p')}"
  end

  def format_slot_time_compact(slot)
    if slot.starts_at.min.zero? && slot.ends_at.min.zero? && (slot.ends_at - slot.starts_at) == 1.hour
      start_meridian = slot.starts_at.strftime("%p")
      end_meridian = slot.ends_at.strftime("%p")

      if start_meridian == end_meridian
        "#{slot.starts_at.strftime('%-I')}–#{slot.ends_at.strftime('%-I')} #{end_meridian}"
      else
        "#{slot.starts_at.strftime('%-I %p')}–#{slot.ends_at.strftime('%-I %p')}"
      end
    else
      format_slot_time(slot)
    end
  end

  def result_availability_summary(result)
    court_count = result.slots_by_court.size
    slot_count = result.slots.size
    "#{court_count} #{'court'.pluralize(court_count)} · #{slot_count} #{'slot'.pluralize(slot_count)}"
  end

  # Merge overlapping intervals across courts for a venue-level overview. Court
  # details remain the source of truth for a continuous booking on one court.
  def venue_availability_ranges(result, search: nil)
    intervals = result.slots.flat_map do |slot|
      windows = search ? search.time_windows : [ [ slot.starts_at, slot.ends_at ] ]
      windows.filter_map do |window_start, window_end|
        starts_at = [ slot.starts_at, window_start ].max
        ends_at = [ slot.ends_at, window_end ].min
        [ starts_at, ends_at ] if ends_at > starts_at
      end
    end

    intervals.sort_by(&:first).each_with_object([]) do |(starts_at, ends_at), ranges|
      if ranges.any? && starts_at <= ranges.last.last
        ranges.last[1] = [ ranges.last.last, ends_at ].max
      else
        ranges << [ starts_at, ends_at ]
      end
    end
  end

  def availability_bar_style(starts_at, ends_at, search)
    duration = (search.play_time_end - search.play_time).to_f
    left = ((starts_at - search.play_time) / duration * 100).clamp(0, 100)
    right = ((ends_at - search.play_time) / duration * 100).clamp(0, 100)
    "left: #{left.round(4)}%; width: #{(right - left).round(4)}%"
  end

  def availability_axis_labels(search)
    midpoint = search.play_time + (search.play_time_end - search.play_time) / 2
    [ search.play_time, midpoint, search.play_time_end ].map do |time|
      time.strftime(time.min.zero? ? "%-I %p" : "%-I:%M %p")
    end
  end

  def format_play_time_window(search)
    return search.day_parts.map(&:capitalize).join(" or ") if search.day_parts.any?
    return "all day" if all_day_window?(search)

    start_label = search.play_time.strftime("%-I:%M %p")
    end_label = search.play_time_end.strftime("%-I:%M %p")
    "#{start_label} – #{end_label}"
  end

  def booking_handoff_date_hint(search)
    return if search.date == Time.zone.today

    "Select #{search.date.strftime('%-b %-d')} on their site"
  end

  def venue_location_link(venue)
    render "searches/location", venue:
  end

  def play_window_presets
    PLAY_WINDOW_PRESETS
  end

  def search_venue_frame_path(venue, search)
    search_venue_path(
      venue.id,
      date: search.date.iso8601,
      play_time: search.play_time.strftime("%H:%M"),
      play_time_end: search.play_time_end.strftime("%H:%M"),
      day_parts: search.day_parts.join(",")
    )
  end

  def venue_frame_status(result)
    if result.error
      "error"
    elsif result.slots.any?
      "available"
    else
      "empty"
    end
  end

  private

  def all_day_window?(search)
    search.play_time.hour.zero? &&
      search.play_time.min.zero? &&
      search.play_time_end == search.play_time + 1.day
  end
end
