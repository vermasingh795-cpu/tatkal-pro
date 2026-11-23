# Tatkal Pro — Android mobile cloud-build starter

This project is designed to be edited and built using GitHub from an Android phone.
You do NOT need to install Flutter on your phone for the GitHub Actions build.

## Build APK from an Android phone

1. Sign in to GitHub in Chrome and create a new repository named `tatkal-pro`.
2. Upload the contents of this folder to the repository root (not the ZIP file itself).
   Ensure `.github/workflows/android-apk.yml` is included.
3. Open the repository's **Actions** tab.
4. Select **Build Tatkal Pro Android APK**.
5. Tap **Run workflow** (or push to `main`, which also triggers a build).
6. Open the completed workflow run and download the `tatkal-pro-android-apk` artifact.
7. Extract the downloaded artifact ZIP; it contains `app-release.apk`.
8. Install the APK on your Android phone. Android may ask permission to install from that browser/file manager.

## Notes

- GitHub account and available Actions minutes are required; availability/quotas depend on the account.
- The workflow generates Android platform files in the cloud and builds a release APK.
- This is an unsigned-for-store, locally installable release APK. Play Store publishing requires a properly managed signing key and store setup.
- Do not commit passwords, OTPs, UPI PINs, signing keys, or real passenger personal data to GitHub.
- The app opens official IRCTC/Indian Railways pages. It does not automate booking, bypass CAPTCHA, or guarantee availability.
- Countdown logic is only an estimate. Verify the train's originating-station departure date and current IRCTC rules.
