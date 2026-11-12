# Spending Jar

A weekly spending tracker that runs as a website and installs on your iPhone like an app. It uses plain HTML, CSS and JavaScript, with no build step.

## Files

| File | What it does |
|---|---|
| `index.html` | The page |
| `style.css` | The look |
| `app.js` | All the app logic (budget, categories, spending list) |
| `manifest.webmanifest` | Tells phones the site can be installed as an app (name, icon, colours) |
| `sw.js` | Service worker, so the app opens without internet |
| `icons/` | App icons, including `apple-touch-icon.png` for the iPhone home screen |

## 1. Try it on your computer

Open `index.html` in a browser. Everything works except offline mode, which only turns on once the site is served over `https://`.

## 2. Put it online (free)

Pick one:

- **Netlify Drop:** go to app.netlify.com/drop and drag the whole `spending-jar` folder onto the page. You get an `https://…netlify.app` link in seconds.
- **GitHub Pages:** push the folder to a GitHub repo, then go to Settings → Pages → deploy from the `main` branch.
- **Vercel or Cloudflare Pages** also work. Import the repo and leave the build command empty.

The site has to be on **https** for installing and offline mode to work. All of these hosts set that up for you.

## 3. Install it on your iPhone

1. Open your link in **Safari**.
2. Tap the **Share** button (the square with an arrow).
3. Tap **Add to Home Screen**, then **Add**.

The jar icon now opens the app full screen, without the Safari bars. Your data stays on your phone.

> Tip: use the home-screen app, not a Safari tab. iPhone Safari can clear data for websites you haven't visited in a while, but installed home-screen apps keep theirs.

## 4. Updating the app

After you change any file, open `sw.js` and bump `VERSION` (for example `jar-v1` to `jar-v2`), then redeploy. Phones pick up the new version the next time they open the app with internet.

## 5. Later: turn it into a real App Store app

These same files can be wrapped into a native iPhone app with **Capacitor**:

```bash
npm init -y
npm install @capacitor/core @capacitor/cli @capacitor/ios
npx cap init "Spending Jar" com.yourname.spendingjar --web-dir .
npx cap add ios
npx cap open ios
```

That opens the project in Xcode. To run it on your phone you need a **Mac with Xcode**, and to publish on the App Store you need a paid **Apple Developer** account.

A cleaner setup is to move the website files into a `www/` folder first and use `--web-dir www`.
