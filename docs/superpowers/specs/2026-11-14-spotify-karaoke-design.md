# Spotify Karaoke — Design Spec

Date: 2026-11-14
Status: Awaiting review

## 1. Summary

A personal, solo-practice karaoke web app. The user logs in with Spotify, picks a
song from search, their playlists or their liked songs, and the app plays a
matching karaoke video from YouTube (instrumental audio with on-screen lyrics).
The user sings into a USB mic and hears their own voice in wired earphones.

Spotify is used only as the song catalog and library. It plays no audio, because
Spotify audio cannot be made instrumental and Spotify provides no lyrics.

## 2. Goals and non-goals

### Goals (version one)

- Spotify login, search, playlists and liked songs.
- Automatic YouTube karaoke video match for any chosen song.
- Video picker with several matches; the chosen video is remembered per song.
- Song queue, including "add whole playlist", with auto-advance.
- Favorites and singing history, persisted in the browser.
- Mic monitoring: input-device picker, monitor volume, reverb.
- Voice-only recording of a take, downloadable.
- A just-for-fun score at the end of each song.

### Non-goals

- Multiple users, shared rooms, or party mode.
- Cloud sync or any backend/database.
- Pitch-accurate scoring against a reference melody.
- Playing Spotify audio, or writing to the user's Spotify account.
- Recording the backing track together with the voice.
- Native mobile or desktop apps. The layout is responsive, but desktop browser
  (Chrome) with a USB mic is the supported target.

## 3. Constraints

- **Single user.** The Spotify app stays in development mode, owned by the user's
  Premium account. No Spotify quota review is needed.
- **No backend.** Static single-page app. All secrets-free: Spotify uses PKCE
  (no client secret); the YouTube API key is public by nature and is restricted
  by HTTP referrer in Google Cloud Console.
- **YouTube Data API quota.** 10,000 units/day; one search costs 100 units, so
  about 100 searches/day. Search results are cached to stay well under this.
- **YouTube terms.** Videos play only through the official IFrame player. No
  downloading, no audio extraction, no hiding the player.
- **Latency.** Browser mic monitoring is only usable with wired output.
  Bluetooth earphones add too much delay; the UI says so.

## 4. Architecture

Vite + React + TypeScript single-page app. No router: one page with panels. The
Spotify OAuth redirect returns to the app root, so it deploys to any static host
(Vercel by default) with no rewrite rules.

```
src/
  spotify/      auth.ts (PKCE, token refresh), api.ts (search, playlists, liked)
  youtube/      search.ts (Data API), query.ts (query builder), player.ts (IFrame wrapper)
  audio/        micEngine.ts (graph, monitoring, reverb), recorder.ts, scorer.ts
  state/        queue.ts (reducer), library.ts (favorites, history, picks)
  storage/      store.ts (typed, versioned localStorage wrapper)
  ui/           components (see section 6)
  App.tsx
```

Each folder exposes a small interface and does not reach into another folder's
internals. `ui/` depends on everything else; nothing depends on `ui/`.

### Configuration

Build-time environment variables:

- `VITE_SPOTIFY_CLIENT_ID`
- `VITE_YOUTUBE_API_KEY`

If either is missing, the app shows a setup screen explaining how to create them
instead of failing silently.

## 5. Modules

### 5.1 Spotify (`spotify/`)

- **Auth:** Authorization Code with PKCE. Scopes: `user-library-read`,
  `playlist-read-private`, `playlist-read-collaborative`.
- Redirect URI is the app origin (`https://<host>/` in production,
  `http://127.0.0.1:5173/` in development; Spotify rejects `localhost`).
- Access and refresh tokens are kept in localStorage. `api.ts` refreshes the
  token on expiry or on a 401 and retries once. If refresh fails, the user is
  logged out and sees the login screen.
- **API surface:** `searchTracks(query)`, `getMyPlaylists()`,
  `getPlaylistTracks(id)`, `getLikedTracks()`. Lists are paged; the UI loads more
  on scroll.
- All functions return a common `Track` shape:
  `{ id, title, artists[], album, albumArtUrl, durationMs }`.

### 5.2 YouTube (`youtube/`)

- **Query builder:** `"<primary artist> <title> karaoke"`, with the title cleaned
  of suffixes such as "- Remastered 2011", "(feat. …)" and "- Radio Edit".
- **Search:** `search.list` with `type=video`, `videoEmbeddable=true`,
  `maxResults=5`. Returns `VideoCandidate[]`:
  `{ videoId, title, channelTitle, thumbnailUrl }`.
- **Caching:** candidates are cached per Spotify track ID for 30 days. A cached
  track costs no quota.
- **Player wrapper:** a thin class over the IFrame Player API exposing
  `load(videoId)`, `play()`, `pause()`, `seek()`, and events `onStateChange`,
  `onEnded`, `onError`.
- **Resolution order when a song starts:** remembered pick → first cached
  candidate → fresh search.

### 5.3 Mic engine (`audio/`)

Audio graph:

```
mic (getUserMedia) ─► inputGain ─┬─► dry ──────────────┬─► monitorGain ─► speakers/earphones
                                 └─► convolver ─► wet ─┤
                                                       └─► MediaStreamDestination ─► recorder
                    inputGain ─► AnalyserNode ─► scorer
```

- `getUserMedia` is called with `echoCancellation`, `noiseSuppression` and
  `autoGainControl` all disabled, and the selected `deviceId`.
- `AudioContext` uses `latencyHint: "interactive"`.
- Reverb is a `ConvolverNode` with a generated impulse response; one "reverb
  amount" slider controls the wet/dry mix.
- Monitoring is **off by default** and toggled by the user, to avoid feedback
  when no earphones are plugged in.
- Controls: input device, monitor on/off, monitor volume, reverb amount, input
  level meter.

**Recorder:** `MediaRecorder` on the processed mic signal (voice with reverb).
Recording starts and stops with the song when "record this take" is enabled. The
finished take can be played back and downloaded as `.webm`. Only the most recent
take is held, in memory; it is not persisted.

**Scorer:** while the video is playing, samples the analyser about 20 times per
second and classifies each frame as voiced or silent using a level threshold
calibrated from the first second of input noise. For voiced frames it estimates
pitch by autocorrelation.

- Participation = voiced frames ÷ total frames, capped at an expected singing
  ratio of 60%.
- Steadiness = share of voiced frames whose pitch is within one semitone of the
  previous voiced frame.
- Score = `round(100 × (0.7 × participation + 0.3 × steadiness))`.

The score screen labels this clearly as a fun score, not a measure of accuracy.
No score is shown if the mic was never enabled.

### 5.4 State and storage (`state/`, `storage/`)

- **Queue:** a pure reducer with actions `add`, `addMany`, `remove`, `move`,
  `next`, `clear`. Holds `Track[]` plus the now-playing track. Videos are
  resolved lazily when a track reaches the front, so adding a 50-song playlist
  costs no quota up front.
- **Library:** favorites (set of tracks), history (most recent first, capped at
  500 entries, each with track, timestamp, videoId and score), and picks
  (`trackId → videoId`).
- **Storage:** one typed wrapper around localStorage with a schema version.
  Keys: `auth`, `queue`, `favorites`, `history`, `picks`, `searchCache`,
  `settings` (device ID, monitor volume, reverb amount, record toggle). Every
  read and write is wrapped in try/catch; corrupt or missing data falls back to
  defaults.

## 6. User interface

One screen with three areas.

- **Browse (left):** tabs for Search, Playlists, Liked, Favorites, History. Each
  track row has "Sing now", "Add to queue" and a favorite star. Playlists have
  "Add all to queue".
- **Stage (center):** the YouTube player, now-playing title, play/pause, skip,
  and "Change video", which opens the candidate list. Choosing a candidate
  swaps the video and saves the pick. When a song ends, a score card shows
  briefly with the take's playback/download controls, then the queue advances.
- **Side (right):** the queue (reorder, remove) and the mic panel.

On narrow screens the three areas stack: stage, then queue/mic, then browse.

## 7. Data flow: singing one song

1. User clicks "Sing now" on a track; it becomes now-playing.
2. The app resolves a video (pick → cache → search) and loads it in the player.
3. On the player's `playing` state, the scorer starts and, if enabled, the
   recorder starts.
4. On `ended` (or skip), scorer and recorder stop. A history entry is written
   with the score. The score card is shown.
5. The queue advances to the next track and repeats from step 2.

## 8. Error handling

| Situation | Behavior |
|---|---|
| Video blocked from embedding (player error 101/150) or unavailable (100) | Automatically try the next candidate; if none remain, show "No playable karaoke video found" with a retry-search button and skip option |
| YouTube search returns nothing | Retry once with a looser query (`"<title> karaoke"`); then show the same empty state |
| YouTube quota exceeded (403 `quotaExceeded`) | Message explaining the daily limit; songs with cached or remembered videos still work |
| Spotify token expired | Silent refresh and one retry; on failure, return to login |
| Spotify rate limit (429) | Wait for `Retry-After`, then retry once |
| Mic permission denied or no device | Mic panel shows how to grant access; karaoke playback still works without the mic |
| Mic device unplugged mid-song | Monitoring and recording stop cleanly; panel prompts to pick a device |
| Missing env configuration | Setup screen with instructions |

## 9. Testing

- **Unit tests (Vitest):** query builder and title cleaning, queue reducer,
  storage wrapper (including corrupt data), score calculation from synthetic
  frame data, PKCE helper functions.
- **API client tests:** Spotify and YouTube clients with mocked `fetch`,
  covering paging, token refresh on 401, 429 handling and quota errors.
- **Component tests (React Testing Library):** browse → queue → now-playing
  flow with a fake player, and the candidate picker saving a pick.
- **Manual checklist** (documented in the README) for what cannot be automated:
  real Spotify login, real YouTube playback and embed-blocked fallback, mic
  monitoring latency with wired earphones, recording download.

## 10. Setup and deployment

The README documents:

1. Creating a Spotify developer app (Premium account) and registering redirect
   URIs for development and production.
2. Creating a YouTube Data API v3 key and restricting it to the site's referrer.
3. Local development (`npm run dev` on `127.0.0.1`).
4. Deploying to Vercel with the two environment variables.

## 11. Known limitations

- Karaoke video quality and availability depend on what exists on YouTube.
- YouTube may show ads in the embedded player.
- Recordings contain the voice only.
- The score does not measure singing accuracy.
- Data lives in one browser; clearing site data erases it.
