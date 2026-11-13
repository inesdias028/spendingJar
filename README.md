# Spending Jar

A money tracker that installs on your iPhone like an app. It shows one **balance** that can be positive or negative:

> balance = starting balance + money in − money out

- **Balance** tab: your balance, this month's money in and out, a quick way to add spending or income (one-off or repeating), and your activity grouped by day.
- **Stats** tab: what you saved (or overspent) each week, month or year, a chart of money in and out, the balance at the start and end, and totals by category.
- **Account** tab: starting balance, recurring items, and sign out.

The app is built with Flutter, using the iOS (Cupertino) widgets: large titles that shrink as you scroll, a translucent tab bar, inset grouped lists, iOS sheets and alerts, and automatic light/dark mode.

## Code

The app lives in [`spending_jar_flutter/`](spending_jar_flutter). Pushing to `main` builds it and publishes it to GitHub Pages (see `.github/workflows/deploy.yml`). Data is stored per user in Firebase (`firestore.rules`).

`spending-jar/` is the older plain HTML version and is not deployed.

## Try it locally without signing in

Demo mode opens straight into sample data that is kept in memory only (nothing is sent to Firebase):

```bash
cd spending_jar_flutter
flutter create --platforms=web --project-name spending_jar .
flutter run -d chrome --dart-define=DEMO=true
```
