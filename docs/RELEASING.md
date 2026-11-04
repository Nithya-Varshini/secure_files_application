# Releasing Kwam

| Build   | Application ID              | Name on the phone |
|---------|-----------------------------|-------------------|
| debug   | `com.nithya.privacyvault.dev` | Kwam Dev        |
| release | `com.nithya.privacyvault`     | Kwam            |

Debug and release builds install side by side. The release ID can never change once the app is on Google Play.

## 1. Create the upload keystore (one time)

```sh
keytool -genkey -v -keystore ~/kwam-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store the keystore and its passwords **outside the repo**, in a password manager, with a backup copy. Use Play App Signing: Google then holds the real app-signing key, and a lost upload key can be reset.

## 2. Point the build at it

Create `android/key.properties`. It is git-ignored, so never commit it.

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=C:/Users/<you>/kwam-upload.jks
```

If this file is missing, a release build is signed with the debug key. That is fine for local testing, but Google Play rejects it.

## 3. Bump the version and build

In `pubspec.yaml`, set `version: <name>+<code>`. The code must go up for every upload.

```sh
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

Upload `build/app/outputs/bundle/release/app-release.aab`. Keep `build/symbols` so stack traces can be decoded later.

## 4. Play Console checklist

- **Icon:** `assets/branding/play_store_icon_512.png`. All icons come from `tool/generate_icon.dart`, so edit that file and run `dart run tool/generate_icon.dart`.
- **Privacy policy URL:** state that no data leaves the device and that the app has no analytics or accounts.
- **Data safety form:** no data collected or shared; data is encrypted in transit (not applicable) and at rest.
- **Permissions:** Camera (document scanner) and Biometric (unlock).
- **Testing:** start with Internal testing, then a Closed test. New personal developer accounts must run a closed test with testers before they can publish to Production.
