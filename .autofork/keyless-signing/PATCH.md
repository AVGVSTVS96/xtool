Sign with a certificate whose key lives elsewhere, and let `xtool sign` do it without installing.

A free team holds one development certificate. When an Xcode on a Mac made it, xtool can read it from Apple but has no key, and used to revoke it to make its own, which breaks every app that Xcode signed.

- A certificate stored without its key still provisions as usual (devices, App IDs, profiles) and signs ad hoc, leaving the real signature to the key's holder.
- `xtool sign <app>` provisions a built .app and signs it in place, with no device connected, and always declines to revoke a certificate.

Once upstream signs with a certificate it holds no key for, and has a sign-only command, this patch is done.
