# Court Finder

Helps players in Cagayan de Oro find where they can book pickleball court time instead of checking each venue's website manually.

## Language

**Venue**:
A place in Cagayan de Oro that offers pickleball courts for rent. v1 monitors a fixed set of five: Pickle Village, Home Court, 0-0-2 Pickle Courts, Champions Field, Paddle Play.
_Avoid_: Facility, club, location

**Booking platform**:
The third-party online reservation system a venue uses. Pickle Village, Home Court, 0-0-2, and Champions Field use Rezerv; Paddle Play uses BookingDyno.
_Avoid_: Booking site, scheduler, portal

**Availability search**:
A query with a date, preferred start time, and session duration that returns venues with at least one matching slot. The player may search today or any future date the venues' booking platforms expose, but not past dates.
_Avoid_: Court search, slot finder

**Session duration**:
How long the player group wants the court for. v1 offers one choice: 1 hour.
_Avoid_: Booking length, session length

**Slot**:
A contiguous block of time at a venue that can be booked for pickleball. A slot matches a search when it starts at or before the player's preferred play time and ends at or after play time plus session duration; it may be longer than the requested duration.
_Avoid_: Session, reservation window

**Search result**:
One venue that has at least one matching slot for the current availability search. Shows the venue name, all matching slot time ranges, and one link to that venue's booking platform. Results are ordered by how close the venue's earliest matching slot starts to the player's preferred play time. Venues with no matching slots are omitted.
_Avoid_: Listing, recommendation

**Availability check**:
A live pull from each venue's booking platform when the player runs a search. All venues are checked in parallel. While the check is in progress, the player sees a loading indicator. Results include the time the check completed so the player knows how fresh they are. If a venue cannot be checked or does not respond in time, its result shows an error instead of slot times; other venues still appear.
_Avoid_: Sync, scrape run, cache refresh

**Booking handoff**:
The player leaves Court Finder and completes the reservation on the venue's own booking platform. Court Finder does not take payment or confirm bookings in v1. The handoff link opens the venue's booking page but cannot pre-select the player's search date — Rezerv, BookingDyno, and Courtogo do not expose a supported URL parameter for it, so those sites default to today. When the search date is not today, Court Finder reminds the player to select that date on the venue site.
_Avoid_: Checkout, in-app booking

**Play time**:
A date and clock time interpreted in Asia/Manila, regardless of where the player is physically located or what their device timezone is set to. Must be now or later — past dates and earlier times today are not valid. Chosen in hourly increments.
_Avoid_: Local time, device time

**Player**:
Anyone using Court Finder to run an availability search. v1 requires no account or login.
_Avoid_: User, member, customer

**Empty search**:
An availability search where every venue was checked successfully but none has a matching slot. The player sees a message naming the requested play time and when the check completed.
_Avoid_: No results, zero availability

**Court**:
A physical pickleball playing surface at a venue. v1 does not require identifying a specific court — only whether the venue has open slots.
_Avoid_: Lane, field
