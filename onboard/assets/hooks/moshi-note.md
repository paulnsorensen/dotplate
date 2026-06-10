# Moshi hook setup

The moshi hooks require the `moshi-hook` binary from [rjyo/moshi](https://github.com/rjyo/moshi).

Install via the `moshi-hook` package in `onboard/catalog/packages.yaml` (macOS only),
or follow the Moshi iOS app's own installer instructions for Linux.

The four hook entries (`moshi-session-start`, `moshi-user-prompt-submit`, `moshi-stop`,
`moshi-permission-request`) should be pasted as siblings under the `hooks:` key in
`agents/hooks/registry.yaml`, not nested under each other.
