<div align="center">

  # Vector 🥃 
  *Wine but a bit stronger*
  
  ![](https://img.shields.io/github/actions/workflow/status/IsaacMarovitz/Vector/SwiftLint.yml?style=for-the-badge)
  [![](https://img.shields.io/discord/1115955071549702235?style=for-the-badge)](https://discord.gg/CsqAfs9CnM)
</div>

## Maintenance Status

Vector is actively maintained again in this fork for Apple Silicon gaming.
Runtime, Steam compatibility, and toolchain updates are tracked here.

<img width="650" alt="Config" src="https://github.com/Vector-App/Vector/assets/42140194/d0a405e8-76ee-48f0-92b5-165d184a576b">

Familiar UI that integrates seamlessly with macOS

<div align="right">
  <img width="650" alt="New Bottle" src="https://github.com/Vector-App/Vector/assets/42140194/ed1a0d69-d8fb-442b-9330-6816ba8981ba">

  One-click bottle creation and management
</div>

<img width="650" alt="debug" src="https://user-images.githubusercontent.com/42140194/229176642-57b80801-d29b-4123-b1c2-f3b31408ffc6.png">

Debug and profile with ease

---

Vector provides a clean and easy to use graphical wrapper for Wine built in native SwiftUI. You can make and manage bottles, install and run Windows apps and games, and unlock the full potential of your Mac with no technical knowledge required. Vector is built on top of CrossOver 22.1.1, and Apple's own `Game Porting Toolkit`.

Translated on [Crowdin](https://crowdin.com/project/vector).

---

## System Requirements
- CPU: Apple Silicon (M-series chips)
- OS: macOS Sonoma 14.0 or later

## Runtime Channel (Fork)

This fork supports a signed runtime channel for `Libraries.tar.gz` updates.

- Setup and publishing guide: [`docs/runtime-channel.md`](docs/runtime-channel.md)
- Runtime metadata location in this repo: [`runtime/Wine`](runtime/Wine)

### Steam Compatibility Runtime

Steam can require a newer Wine build than the bundled runtime. This fork supports a Steam-specific override runtime:

```bash
scripts/runtime/install_steam_compat_wine.sh
```

The script downloads Wine 11 into `~/Library/Application Support/com.isaacmarovitz.Vector/Compatibility/SteamWine`,
then stores the override paths in `com.isaacmarovitz.Vector` defaults so Steam launches use that runtime automatically.

Compatibility-runtime Steam launches use a lean argument set by default for better responsiveness.
If a machine needs conservative startup flags, enable safe mode:

```bash
defaults write com.isaacmarovitz.Vector steamForceSafeLaunchFlags -bool true
```

### Performance Defaults (Fork)

This fork applies game-focused Wine defaults:

- `WINEDEBUG=-all` for lower logging overhead during game launches.
- DXVK state cache is enabled with a per-bottle cache path.
- DXVK logging defaults to `none` when DXVK is enabled.

To temporarily restore verbose Wine logs for troubleshooting:

```bash
defaults write com.isaacmarovitz.Vector wineDebugLevel fixme-all
```

To revert to the optimized default:

```bash
defaults delete com.isaacmarovitz.Vector wineDebugLevel
```

## Homebrew

Vector is on homebrew! Install with 
`brew install --cask vector`.

## My game isn't working!

Some games need special steps to get working. Check out the [wiki](https://github.com/IsaacMarovitz/Vector/wiki/Game-Support).

---

## Credits & Acknowledgments

Vector is possible thanks to the magic of several projects:

- [msync](https://github.com/marzent/wine-msync) by marzent
- [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) by Gcenx and doitsujin
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) by KhronosGroup
- [Sparkle](https://github.com/sparkle-project/Sparkle) by sparkle-project
- [SemanticVersion](https://github.com/SwiftPackageIndex/SemanticVersion) by SwiftPackageIndex
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) by Apple
- [SwiftTextTable](https://github.com/scottrhoyt/SwiftyTextTable) by scottrhoyt
- [CrossOver 22.1.1](https://www.codeweavers.com/crossover) by CodeWeavers and WineHQ
- D3DMetal by Apple

Special thanks to Gcenx, ohaiibuzzle, and Nat Brown for their support and contributions!

---

<table>
  <tr>
    <td>
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="./images/cw-dark.png">
          <img src="./images/cw-light.png" width="500">
        </picture>
    </td>
    <td>
        Vector doesn't exist without CrossOver. Support the work of CodeWeavers using our <a href="https://www.codeweavers.com/store?ad=1010">affiliate link</a>.
    </td>
  </tr>
</table>
