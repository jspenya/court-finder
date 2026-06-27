# frozen_string_literal: true

module Availability
  Slot = Data.define(:starts_at, :ends_at, :court) do
    def label
      time_label = "#{starts_at.strftime('%I:%M %p')} – #{ends_at.strftime('%I:%M %p')}"
      court.present? ? "#{court}: #{time_label}" : time_label
    end
  end
end
