fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac verify_api

```sh
[bundle exec] fastlane mac verify_api
```

Check the API key works: list the team's certificates and bundle ids

### mac developer_id_cert

```sh
[bundle exec] fastlane mac developer_id_cert
```

Create (or download) the Developer ID Application certificate into the login keychain

### mac release

```sh
[bundle exec] fastlane mac release
```

Build, sign with Developer ID, notarize, and publish a GitHub release. fastlane release version:1.0.0

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
