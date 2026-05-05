# Steam grid art for non-Steam shortcuts

## File layout

All artwork for both Steam and non-Steam library tiles lives under:

```
~/.local/share/Steam/userdata/<UID>/config/grid/
```

For a non-Steam shortcut with AppID `N`, Steam looks up:

| Filename             | Meaning                                        | Nominal size |
|----------------------|------------------------------------------------|--------------|
| `Np.jpg` / `Np.png`  | Portrait capsule — the main library tile      | 600×900      |
| `N.jpg`  / `N.png`   | Wide header capsule — Home/"Recent games"      | 460×215      |
| `N_hero.jpg / .png`  | Hero banner on the game detail page            | 1920×620     |
| `N_logo.png`         | Transparent logo overlay on the hero           | any          |
| `N_icon.png / .ico`  | Small icon (tab, notifications)                | any          |

Jpg and png are interchangeable; Steam picks whichever exists.

## Downloading from the Steam CDN

If the same game exists on Steam, its official artwork is served at:

```
https://cdn.akamai.steamstatic.com/steam/apps/<STEAM_APPID>/<asset>
```

Useful assets:

| Remote                      | Local target (for grid `N`) |
|-----------------------------|------------------------------|
| `library_600x900_2x.jpg`    | `Np.jpg`                     |
| `header.jpg`                | `N.jpg`                      |
| `library_hero.jpg`          | `N_hero.jpg`                 |
| `logo.png`                  | `N_logo.png`                 |
| `capsule_616x353.jpg`       | (alternative header)         |

All are fetched HTTPS with no auth. `steam-shortcut grid` does this:

```bash
steam-shortcut grid --appid <shortcut-appid> --steam-appid <steam-appid>
```

## Finding the Steam AppID

- On the Steam store: URL is `store.steampowered.com/app/<AppID>/…`.
- `steamdb.info/search/` is a faster lookup.
- For your own Steam-installed copy: look under
  `~/.local/share/Steam/steamapps/appmanifest_<AppID>.acf`.

## SteamGridDB (community art)

If the Steam store artwork is missing or you want alternatives,
`steamgriddb.com` has a large community library. It exposes a REST API
at `https://www.steamgriddb.com/api/v2/` (requires a free API key)
for programmatic download, and a web UI for manual browsing.
`steam-shortcut grid` does not currently integrate with it — drop files
into the grid folder with the naming convention above and Steam will
pick them up on next restart.

## After replacing art, force a refresh

Steam caches art. If a changed file isn't showing:

- Fully close Steam (`steam -shutdown`), then restart.
- Right-click the game → Manage → Set custom artwork → Reset to default.
