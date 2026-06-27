# Read availability via unofficial booking-platform HTTP endpoints

Court Finder pulls slot availability from Rezerv and BookingDyno using the same HTTP endpoints their public booking widgets call — not HTML scraping, and not a documented official API. Rezerv exposes JSON at `customer-api.rezerv.co` (requiring a venue-specific `Origin` header, not player login). BookingDyno uses Next.js server actions plus an anonymous visitor token from `/api/public/requestToken`. We chose this because it returns structured slot data with less fragility than DOM scraping, works without player accounts, and avoids blocking v1 on platform partnerships. The trade-off is coupling to undocumented contracts that can change without notice; each platform gets a dedicated adapter and per-venue check failures degrade gracefully.

**Considered options:** HTML scraping (rejected — brittle on redesign), waiting for official APIs (rejected — blocks v1; no public API today).

**Consequences:** Adapter maintenance when platforms change. Server-side fetch only — credentials and platform IDs never exposed to the player.
