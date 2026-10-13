Sign apps with their own bundle ID and app group IDs, the ones Xcode uses, instead of xtool's `XTL-<team>.` copies.

The copies make an xtool install a different app from the same app installed by Xcode: it lands next to the original instead of updating it, can't see its data, and code that names its own app group can't open it.

xtool prefixes IDs because an explicit App ID belongs to one team, and its users often sideload apps whose developer already registered the ID. So keep the prefix as the fallback:

- Reuse an ID the team already has, its own before the prefixed one, so apps xtool already installed stay the same app.
- Otherwise register the app's own ID, and take the prefixed one only when Apple says another team owns it.
- Extensions follow their app's choice, since iOS requires an extension's ID to start with its app's.
- App groups work the same way, each on its own.
