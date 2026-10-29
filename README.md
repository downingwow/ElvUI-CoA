# ElvUI-CoA — Interface Replacement for Conquest Reborn

ElvUI-CoA packages a legacy ElvUI interface for Ascension Conquest of Azeroth / Conquest Reborn. Based on the supplied ElvUI 7.28 package, it provides configurable action bars, unit frames, nameplates, bags, chat, tooltips, auras, data displays, maps and interface skins.

## Included components

| Folder | Purpose |
| --- | --- |
| `ElvUI` | Main interface replacement and bundled libraries |
| `ElvUI_OptionsUI` | Configuration panels |
| `ElvUI_AddOnSkins` | Supported addon skins |
| `ElvUI_CoAResources` | CoA class resource bars |
| `ElvUI_CoACXtra` | Who search, server-message/restart displays and item-error handling |
| `ElvUI_ProfileInstaller` | Profile export and installation tools |

## Installation and configuration

Download **v1.0.1** from [Releases](https://github.com/downingwow/ElvUI-CoA/releases) and copy all six folders directly into `Interface/AddOns`, keeping their names unchanged. Back up existing addon folders and WTF settings before replacing them. Open configuration with `/ec` or `/elvui`; `/moveui` opens frame movement.

All six components report **1.0.1-CoA**. Upstream authors and versions are retained in metadata. The core preserves the upstream 7.28 profile-migration schema and existing SavedVariables rather than rerunning old migrations.

## Release scope

v1.0.1 is a maintenance release for version labels and release documentation. It does not claim new map fixes, minimap-button expansion or new gameplay behavior. ElvUI is an interface replacement; DragonUI coexistence is not a release requirement. Map pins, combat behavior and other live-client interactions still require in-game testing.

Original contributors include **Elv, Bunny, Paddy, Azilroka, Sortokk**, and those listed in the in-game Credits. See `CHANGELOG-CoA.md` for the CoA release history.

## Compatibility and support

Target: Ascension Conquest of Azeroth / Conquest Reborn, legacy WoW 3.3.5a (Interface 30300). Source and package checks do not establish live realm compatibility. Report the addon version, UI addons, and full Lua error when filing an issue. Preserve your WTF SavedVariables when updating.

Maintainer: **Uncle Bone** · [GitHub support](https://github.com/downingwow). This is a community-maintained adaptation. Original authors retain their credits; bundled license and third-party attribution notices remain applicable.
