# Proton-Style Patch Sources

Vector catalogs these upstream compatibility patches so they can be reviewed,
checksummed, and promoted intentionally. They are not applied by

automation until copied into a validated vector-* runtime patchset.

Primary source: https://github.com/GloriousEggroll/wine-ge-custom.git
Branch: master
Version: Lutris Wine GE-Proton8-26

This catalog focuses on:
- Media Foundation and web-auth-adjacent plumbing
- Windows networking connectivity stubs used by modern launch/auth flows
- WinINet cleanup patches used by Wine-GE
- D3DX11 texture-from-memory fixes
- XAudio/X3DAudio import-library coverage
