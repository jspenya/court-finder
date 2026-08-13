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

  def format_play_time_window(search)
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
      play_time_end: search.play_time_end.strftime("%H:%M")
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
