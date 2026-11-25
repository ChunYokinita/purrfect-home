# Purrfect Home

Purrfect Home is a cozy cat-care and room decoration game. Look after Mochi, earn coins, and turn a little starter room into a home. Flutter handles the interface, Flame draws the animated isometric room, and SharedPreferences saves progress on the device or in the browser.

## Run locally

Use Flutter 3.47.6 or later with Dart 3.13.5 or later. From the repository root:

```sh
flutter pub get
flutter run
```

Flutter will list available devices if more than one is connected. Use `flutter run -d chrome` for the browser. The project includes Android and iOS runners. Running iOS requires macOS and Xcode.

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

The Android build uses the default Flutter debug signing configuration for local installation.

## Play

- **Home** shows Mochi’s fullness, energy, happiness, and bond. Feed a meal, pet Mochi, and play. Mochi also moves, naps, looks out the window, and uses suitable furniture independently.
- **Market** sells food, reusable toys, furniture, and décor. Purchases go to **Storage**.
- **Storage** lets you use food or toys and place furniture. Furniture uses the footprint shown on its card. In **Edit room**, tap a piece to move it or put it back in Storage. Highlighted tiles show where the piece fits.
- **Journal** tracks daily and long-term goals. Claim the rewards after completing them.
- The **Coin jar** earns one coin every 30 seconds, including time away, up to 120 available coins. Collect them from Home. Use coins and bond to grow the room from 5 × 5 to 6 × 6 and then 7 × 7.

## Artwork and fonts

The game uses original painted room art and a 4 × 3 sprite sheet at `assets/images/cat.png`. The cat art was created with OpenAI image generation using this source prompt:

> Create a single production sprite source sheet for an original cozy isometric pet simulator. Real transparent background. Exactly SIX separate clean cutout drawings in a regularly spaced 3-column by 2-row landscape grid, with wide transparent space between drawings and around the border. Top row from left: standing idle on four feet, taking a forward walking step, playful pounce with front legs extended. Bottom row from left: curled up asleep, sitting upright looking content, standing on hind legs with front paws up scratching (no object). Show the exact same small orange cream tabby cat in all six poses, warm ginger striped back and forehead, pale muzzle and chest, curled expressive tail and dot eyes. Each full-body cat faces screen left in a slightly elevated three-quarter side view, maintaining matching proportions and palette across the sheet. Make the cat readable at 40 pixels: silhouette first, rounded simple geometry, understated dark brown outline, short legs, warm hand-painted flat color in a cottagecore casual game style, with very little surface texture. Each drawing stays wholly inside its own equally-sized grid cell. No panels, grid lines, text, labels, props, furniture, additional cats, ground shadows, sparkles or symbols. Transparent wherever there is no cat.

Fraunces and Nunito Sans are distributed under the SIL Open Font License. The license files are in `assets/fonts/`.
