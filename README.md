# Savepoint

A private, single-player video game diary, built in Flutter for Android. It takes the best parts of Letterboxd, Serializd, Trakt and Backloggd and keeps everything on your phone.

## Install on your phone

```bash
flutter build apk --release
```

Copy `build/app/outputs/flutter-apk/app-release.apk` to your phone and open it. You'll need to allow "Install unknown apps" once. You can also plug in your phone with USB debugging on and run `flutter install`.

## Connect IGDB (one-time, free)

Savepoint uses IGDB, the same database Backloggd uses, for covers, search and discovery.

1. Go to https://dev.twitch.tv/console/apps/create. You need a Twitch account with 2FA turned on.
2. Register an app:
   - Name: anything
   - OAuth Redirect URL: `http://localhost`
   - Category: Application Integration
   - Client type: Confidential
3. Copy the **Client ID**, press **New Secret**, and copy the secret.
4. In the app, go to Settings → IGDB connection, paste both, and tap **Test & save**.

Your keys stay on the device and are never put in backups. You can also add games without IGDB using "Add manually".

## Connect Xbox (optional, free)

Savepoint can import your Xbox and PC Game Pass history: every game you've played, plus hours, achievements and gamerscore. Microsoft no longer lets personal accounts register their own Xbox Live apps, so this goes through [OpenXBL](https://xbl.io), a free service that reads your Xbox data with your permission.

1. Sign in at https://xbl.io with the Microsoft account linked to your Xbox profile.
2. On your xbl.io profile page, create an API key and copy it.
3. In the app, go to Settings → Xbox, paste the key, and tap **Connect**.
4. Tap **Sync my Xbox games**. Every game is matched to IGDB, and you review the list before anything is added. You can fix matches, change statuses and untick games you don't want.

How the import behaves:
- New games get a suggested status: 100% if every achievement is unlocked, Playing if played in the last 30 days, Played otherwise.
- Games already in your library keep their status and rating. Only the Xbox playtime added since your last sync is added to them, so syncing again never double-counts.
- Each linked game's page shows its Xbox achievements, gamerscore and last-played date. Your gamertag and gamerscore appear on your Profile.
- A sync uses 3–4 OpenXBL calls. Free keys allow about 150 calls an hour.

The key stays on the device and is never put in backups.

## Features

- **Library**: 8 statuses (Playing, Completed, 100%, Played, Shelved, Abandoned, Backlog, Wishlist), half-star ratings, likes, platform, tags, priority and private notes. Grid and list views, 8 sort orders, and filters by platform, genre, tag and reviewed.
- **Reviews**: reviews with a spoiler veil, plus a feed of everything you've written.
- **Diary**: grouped by month. Milestones (started, beaten, 100%, shelved, abandoned) are logged automatically, and you can add past sessions by hand. If you pick the wrong status by mistake, changing it within 10 minutes removes the auto-entry.
- **Play-session timer**: start a session and a timer bar stays above the navigation. It survives the app being closed. When you stop it, you can log the minutes, a note, the platform and an optional new status.
- **Game pages**: parallax art, IGDB and critic scores, time-to-beat compared with your own playtime, screenshots and trailers, release dates per platform, DLC, remakes, similar games, links and your own history.
- **Discover**: trending, most anticipated, fresh releases, all-time greats and hidden gems, plus 26 genre and mood pages with infinite scroll. Rails are cached, so the page opens instantly.
- **Home**: now-playing cards with progress, a yearly goal ring with pace tracking, up next (sorted by priority), release-radar countdowns and recent activity.
- **Stats** (per year or all-time): finished games and hours by month, an activity heatmap, streaks, weekday patterns, top genres and platforms, most played, highest rated, rating spread, release eras, completion rate and a backlog forecast.
- **Lists**: ranked or unranked, drag to reorder, swipe to remove with undo.
- **Profile**: a top-5 favorites shelf and a Letterboxd-style rating histogram.
- **Pick for me**: a slot-machine spin over your backlog, filtered by how much time you have and by platform.
- **Data**: JSON backup and restore, plus CSV export.
- **Accents**: 6 accent colors (Ember, Volt, Plasma, Ion, Ultra, Solar).

## Your data

Everything is stored in SQLite on the phone and loaded into memory at launch, so every screen is instant. **Export a backup now and then** (Settings → Export backup). If you uninstall the app, the backup is your only copy.

## Dev notes

- `flutter run --dart-define=SEED=true` fills the app with demo data so you can try the UI. Normal builds never include it.
- Code layout: `lib/store.dart` (state and persistence), `lib/igdb.dart` (API), `lib/screens/*`, `lib/widgets/*`, `lib/theme.dart` (palette and type).
