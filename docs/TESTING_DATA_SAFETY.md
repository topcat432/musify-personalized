# Phone test data safety

Until stable Android signing is configured, GitHub-hosted debug APKs may not install over one another. Uninstalling the app deletes its private local data.

Before uninstalling any test build:

1. Open **Settings**.
2. Scroll to **Tools**.
3. Tap **Back up user data**.
4. Choose a folder inside **Documents** or **Download**.
5. Confirm that `user.hive` and `settings.hive` were created.

After installing a replacement build:

1. Open **Settings → Tools → Restore user data**.
2. Select both backup files.
3. Restart the app after the restore completes.

The `user.hive` backup contains Spotify import records, matcher progress, Favorites, playlists, and other user data stored in the `user` Hive box. Downloads and cache data are not part of this backup.
