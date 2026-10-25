# Manhunt

Files: `schema.sql` (database and all game rules) and `index.html` (the whole client). No server to run.

## Setup
1. Create a free project at supabase.com.
2. **Authentication → Providers → Anonymous sign-ins**: turn on.
3. **SQL Editor**: paste and run `schema.sql`.
4. **Project Settings → API**: copy the Project URL and the `anon` public key into the top of `index.html` (`SB_URL`, `SB_KEY`). Never use the `service_role` key.
5. Host `index.html` over **HTTPS** (phones block GPS on plain HTTP). Netlify Drop, Cloudflare Pages, GitHub Pages and Vercel all work: upload the file as-is.

## How a match works
- Host creates a lobby, draws the zone by tapping the map (drag dots to adjust), sets rules, shares the invite link.
- Everyone taps **Enable location**. The host can start once everyone has, with 2 to 10 players.
- Roles are picked randomly on the server. Hunters see only anonymous hiders ("Hider A") at their last released position.
- **Hunters get hider positions every 5 minutes by default** (host can change it, minimum 30 s). Hiders' phones still report every few seconds so the server can check the boundary and checkpoints, but snapshots are only released on the schedule.
- Match length counts from the **end** of the head start.

## Rules enforced server-side
Role assignment, timers, snapshot release, catches (one per hider), checkpoint completion (needs 2 good fixes inside the radius), checkpoint time reduction, boundary elimination (needs accurate fixes and the grace period), escapes, scores. Tables are locked; clients can only call the functions in `schema.sql`, and `state()` returns only what the caller's role may see.

## Known limits
- Not tested on real phones or with 10 players yet. Run the checklist below before trusting it.
- Browsers pause GPS when the screen locks. Players must keep the page open and the screen awake (it requests a wake lock).
- Updates are polled every 3 s, not pushed.
- Checkpoints can't detect water or private property; the host should choose a safe zone.
- Hunters are not boundary-eliminated, only hiders. No pause, spectate or host-transfer options.
- Disconnected players keep their role and progress; there is no auto-elimination for disconnecting.

## Test checklist
Two phones plus a laptop tab: create and join, start with 2 players, hunter sees no hider position until the head start ends, snapshot countdown matches the interval, checkpoint appears inside the zone, walking to it reduces survival time, walking out of the zone eliminates after the grace period, catch updates the leaderboard once, close and reopen the tab (you stay in your role), rematch resets everything.
