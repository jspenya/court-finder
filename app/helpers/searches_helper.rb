# frozen_string_literal: true

module SearchesHelper
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
    start_label = search.play_time.strftime("%-I:%M %p")
    end_label = search.play_time_end.strftime("%-I:%M %p")
    "#{start_label} – #{end_label}"
  end
end
