# Putting Even on the App Store

Everything technical is ready: the app has **Delete Account** and a **Privacy Policy** link, there's a page for the policy, screenshots are made automatically, and a GitHub workflow builds, signs and uploads the app. No Mac is needed.

What's left needs your Apple account, so only you can do it. Follow the steps in order. Steps 1–5 are done once; after that, step 6 is all it takes to send a new version.

---

## 1. Join the Apple Developer Program

1. Go to **developer.apple.com/programs/enroll** and sign in with your Apple ID.
2. Enrol as an **Individual**. The fee is 99 USD a year (shown in euros in Europe).
3. Wait for Apple's email that the membership is active (usually 1–2 days).

## 2. Find your Team ID

**developer.apple.com/account** → **Membership details** → **Team ID**: 10 letters and numbers, like `A1B2C3D4E5`. Keep it for step 4.

## 3. Register the app and create an API key

**a. Register the bundle ID**

developer.apple.com/account → **Certificates, IDs & Profiles** → **Identifiers** → **+** → **App IDs** → **App** →
- Description: `Even`
- Bundle ID: **Explicit**, `io.github.inesdias028.even`
- Leave all capabilities off → **Continue → Register**

**b. Create the app in App Store Connect**

**appstoreconnect.apple.com** → **Apps** → **+** → **New App**:
- Platforms: **iOS**
- Name: `Even – Money In & Out` (App Store names must be unique, and plain "Even" is probably taken. The name under the icon on the phone stays **Even**.)
- Primary language: English (U.S.) or Portuguese (Portugal)
- Bundle ID: `io.github.inesdias028.even`
- SKU: `even-ios`
- User access: Full Access

**c. Create an App Store Connect API key** (lets GitHub sign and upload for you)

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** → **+**:
- Name: `GitHub`
- Access: **Admin** (needed so Apple's cloud signing can create the certificate)
- **Generate**, then **Download API Key**. You get a file `AuthKey_XXXXXXXXXX.p8`. **It can only be downloaded once**, so keep it somewhere safe and never share it.
- Note the **Key ID** (next to the key) and the **Issuer ID** (at the top of the page).

## 4. Give GitHub the four secrets

github.com/inesdias028/spendingJar → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Add these four:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | your Team ID from step 2 |
| `ASC_KEY_ID` | the Key ID from step 3c |
| `ASC_ISSUER_ID` | the Issuer ID from step 3c |
| `ASC_KEY_P8` | open the `.p8` file in Notepad and paste **all** of it, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

Secrets are encrypted: nobody, not even you, can read them back on GitHub.

## 5. Make sure the privacy page is online

The policy is `privacy.html` in this project. It's published with the website once the iPhone app is merged into `main`, at:

**https://inesdias028.github.io/spendingJar/privacy.html**

Open it in a browser to check before submitting.

## 6. Send a build to TestFlight

github.com/inesdias028/spendingJar → **Actions** → **Send iPhone app to TestFlight** → **Run workflow**.

After about 20 minutes it's uploaded. Apple then processes it (5–30 minutes). It shows up in App Store Connect → your app → **TestFlight**.

**To install it on your iPhone with TestFlight:** App Store Connect → TestFlight → **Internal Testing** → **+** → add yourself → install the **TestFlight** app from the App Store and accept the invite. TestFlight builds last 90 days, with no 7-day limit.

## 7. Fill in the App Store page and submit

App Store Connect → your app → **iOS App 1.0**.

### Screenshots

Use the screenshots made by the **Build iPhone app** workflow (6.9-inch iPhone, the size Apple asks for):
**github.com/inesdias028/spendingJar/tree/ci-screenshots/app-store**

Upload `1-balance`, `2-stats`, `3-recurring` and `4-account` under **iPhone 6.9" Display**.

### Texts (copy and paste)

**Subtitle** (max 30 characters)
```
Your balance, positive or not
```

**Promotional text**
```
Money in, money out, and one number that tells you where you stand.
```

**Description**
```
Even keeps track of one number: your balance.

Add what you spend and what you earn in a couple of taps, and Even shows whether you're in the plus or in the minus. Green when you're positive, red when you're not.

• Spending and income: pick a category, type the amount, done
• Optional notes, like "Dinner with Ana"
• Repeats: salary, rent or subscriptions are added automatically every week, month or year
• All your activity, grouped by day
• Monthly stats: what you saved or overspent, a day-by-day chart, spending by category and the last 12 months
• A starting balance, for what you had (or owed) before you began
• Syncs with the Even website, so your data is the same everywhere
• Light and dark mode

No ads, no tracking, no bank connection needed. You can delete your account and all your data at any time from the app.
```

**Keywords** (max 100 characters, separated by commas)
```
balance,budget,expenses,spending,income,money,savings,finance,tracker,personal finance
```

**Support URL**
```
https://github.com/inesdias028/spendingJar
```

**Privacy Policy URL**
```
https://inesdias028.github.io/spendingJar/privacy.html
```

**Category:** Finance. **Price:** Free. **Age rating:** answer "None" to everything (4+).

**Copyright:** `2026` followed by your name.

### App Privacy ("nutrition label")

App Store Connect → **App Privacy** → **Get Started** → "Yes, we collect data" → tick:

| Data type | Used for | Linked to the user? | Tracking? |
|---|---|---|---|
| **Contact Info → Email Address** | App Functionality | Yes | No |
| **Financial Info → Other Financial Info** (the amounts you enter) | App Functionality | Yes | No |
| **User Content → Other User Content** (notes) | App Functionality | Yes | No |
| **Identifiers → User ID** (your Firebase account id) | App Functionality | Yes | No |

Nothing else: no location, no analytics, no ads, no tracking.

### App Review information

Apple's reviewers need to sign in. Create an account just for them: open Even, tap **New here? Create an account**, and use an email you control (for example a Gmail address with `+review` added, like yourname+review@gmail.com) and a password. Put that email and password in **Sign-In Information**.

Notes for the reviewer:
```
Even is a personal balance tracker. Sign in with the demo account above. Add an amount on the Balance tab by typing it and tapping a category. Account deletion: Account tab → Delete Account.
```

### Export compliance

Already answered in the app (it uses no special encryption), so Apple won't ask.

### Submit

Under **Build**, pick the build from TestFlight → **Add for Review** → **Submit to App Review**. Review usually takes 1–3 days. If Apple asks for changes, you get a message in App Store Connect.

### Trader status (EU)

In App Store Connect → **Business** (or when Apple asks), say whether you're a **trader**. For a free personal app you normally aren't. If you are, your name, address and contact details are shown on the App Store page.

---

## Sending an update later

1. Change the code and push.
2. Raise **MARKETING_VERSION** in `ios/project.yml` (for example `1.0` → `1.1`). The build number goes up by itself.
3. Run **Send iPhone app to TestFlight** again, then in App Store Connect add a new version, pick the build and submit.
