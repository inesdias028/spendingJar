# Even for iPhone (native SwiftUI app)

This folder is the native iPhone version of Even, written in Swift with SwiftUI, Apple's own toolkit. It has the same features as the website: balance, spending and income with notes, repeats, categories, activity by day, monthly stats, recurring items and starting balance.

It uses the **same Firebase account and data** as the website, so anything you add on the iPhone shows up on the website and the other way round.

## How it is built

This computer runs Windows, and iPhone apps can only be built on a Mac. GitHub lends a Mac for free:

1. Every push that changes `ios/` starts the **Build iPhone app** workflow (`.github/workflows/ios.yml`).
2. On a GitHub Mac it makes the Xcode project from `project.yml` (with XcodeGen), builds the app, and packs it as **`Even.ipa`**.
3. The `.ipa` is saved on the run page under **Artifacts → Even-ipa**, for 30 days.

The app is built **unsigned**. It's signed on your PC, with your own Apple ID, when you install it.

## Installing it on your iPhone from Windows (free)

You need: the iPhone, a cable, your Apple ID, and one of these free Windows programs.

### 1. Get Even.ipa

1. Open **github.com/inesdias028/spendingJar/actions** and click the latest green **Build iPhone app** run.
2. At the bottom, under **Artifacts**, click **Even-ipa**. You need to be signed in to GitHub.
3. Unzip the download. Inside is `Even.ipa`.

### 2a. With Sideloadly (simplest)

1. Install **Sideloadly** from sideloadly.io. It also needs **iTunes** and **iCloud** for Windows (the versions from Apple's website, not the Microsoft Store).
2. Connect the iPhone with the cable, unlock it, and tap **Trust** if asked.
3. Open Sideloadly, drag `Even.ipa` into it, type your Apple ID, and click **Start**. Enter your Apple ID password and the 6-digit code when asked. They go to Apple, not to anyone else.
4. On the iPhone, the first time only:
   - **Settings → Privacy & Security → Developer Mode → On**, then restart the phone.
   - **Settings → General → VPN & Device Management →** tap your Apple ID **→ Trust**.
5. Open **Even** and sign in with the same email and password as on the website.

### 2b. With AltStore (refreshes itself)

1. Install **AltServer** for Windows from altstore.io (it also needs iTunes and iCloud from Apple's website) and use it to install the **AltStore** app on your iPhone.
2. Copy `Even.ipa` to the iPhone (for example with iCloud Drive), open AltStore → **My Apps → +**, and pick it.
3. Keep AltServer running on the PC: AltStore then renews the app over Wi-Fi by itself.

### Limits of a free Apple ID

- The installation lasts **7 days**. After that the app won't open until you install it again (Sideloadly: do step 2a.3 again; AltStore does it for you). **Your data is safe**: it's in your account.
- At most **3** apps installed this way at the same time.
- No App Store or TestFlight. For those you need the paid Apple Developer account (99 USD a year). The same code works then; only signing is added.

## Signing in

- Use your **email and password**.
- If you created your account with **Google** on the website, type your email and tap **Forgot password?** to set a password, then sign in with it. Google sign-in in the iPhone app needs the app registered in Firebase first (see below).

## Working on it on a Mac (optional)

```bash
brew install xcodegen
cd ios
xcodegen generate
open Even.xcodeproj
```

With a Mac you can run it in the iPhone simulator, or on your phone straight from Xcode with your free Apple ID.

## Firebase notes

- No Firebase setup is needed to start. The app uses the same public settings as the website (`Auth.swift`).
- **Recommended later:** in the Firebase console, open the project → **Add app → iOS**, use the bundle ID `io.github.inesdias028.even`, download **GoogleService-Info.plist** and put it in `ios/Even/`. The app uses it automatically when it's there. This is also the first step for Google sign-in.
- If sign-in says requests are blocked, the API key may be limited to websites. Allow iOS apps for it in Google Cloud console → APIs & Services → Credentials.

## Files

| File | What it does |
|---|---|
| `project.yml` | Describes the Xcode project (XcodeGen turns it into `Even.xcodeproj`) |
| `Even/EvenApp.swift` | Starts the app, Firebase, the sign-in check and the three tabs |
| `Even/Models.swift` | Entries, categories, recurring items, dates and euro formatting |
| `Even/Store.swift` | Reads and saves your data in Firebase and works out the balance |
| `Even/Auth.swift` | Firebase settings and sign-in |
| `Even/Views/` | The screens: Balance, Stats, Account, Recurring, sign-in |
| `Even/Assets.xcassets` | App icon, logo and the teal accent colour |
