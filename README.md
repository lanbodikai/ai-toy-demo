# AI Toy iOS Demo

An iPhone SwiftUI story-comprehension app with Mandarin narration, English subtitle support, push-to-talk transcription, local answer evaluation, and bundled audio cues.

## Included

- Complete `AIToy.xcodeproj` source project
- SwiftUI app source
- Bundled story and feedback audio
- Privacy manifest
- Unit tests

The backend source and production credentials are intentionally not included.

## Open and run

Requirements: a Mac with Xcode 16 or later.

1. Clone or download this repository.
2. Open `AIToy.xcodeproj` in Xcode.
3. Select the `AIToy` target and choose your Apple Developer team under **Signing & Capabilities**.
4. Change the bundle identifier from `com.riselink.aitoy` if it is not available to your team.
5. Add an App Icon before distributing the app. The project currently does not include the required 1024 x 1024 App Store icon.
6. Select an iPhone simulator and run the `AIToy` scheme.

## Backend

The app defaults to the deployed HTTPS backend at:

```text
https://api.mousefit.pro/ai-toy
```

No backend account, SSH key, or OpenAI API key is required to build the iOS app. The app requests short-lived client credentials from the backend at runtime.

For intentional local testing, add the `AIToyBackendURL` environment variable to the Xcode Run scheme and point it to a compatible local server.

## TestFlight

1. Create an iOS app record in App Store Connect whose bundle ID matches the Xcode target.
2. In Xcode, select **Any iOS Device (arm64)**.
3. Choose **Product > Archive**.
4. In Organizer, choose **Distribute App > App Store Connect > Upload**.
5. After Apple processes the build, configure testers from the TestFlight tab in App Store Connect.

Increase the build number before uploading a replacement build.

## Tests

Run the iOS test targets from Xcode with **Product > Test**, or use:

```sh
xcodebuild -project AIToy.xcodeproj -scheme AIToy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

## Security

Do not commit backend `.env` files, OpenAI API keys, Oracle SSH keys, signing certificates, or Xcode user data.
