# Third-Party Notices

This project bundles security payload collections so verified Docker builds do
not depend on mutable downloads during the asset-installation stage.

## PayloadsAllTheThings

- Source: <https://github.com/swisskyrepo/PayloadsAllTheThings>
- Bundled path: `PayloadsAllTheThings/`
- License: [MIT](PayloadsAllTheThings/LICENSE)

## payload-box collections

- Source organization: <https://github.com/payload-box>
- Bundled path: `payload-box/`
- License files remain alongside their respective collections.

## CyberStrike

- Source: <https://github.com/CyberStrikeus/CyberStrike>
- Installed package: `@cyberstrike-io/cyberstrike@latest`
- Image path: `/opt/security-tools/cyberstrike/`
- License: [GNU Affero General Public License v3.0 only](https://github.com/CyberStrikeus/CyberStrike/blob/main/LICENSE)
- Resolved package and native-platform versions are recorded during each image
  build in `/opt/security-manifest/resolved-versions.txt`.

The local CyberStrike reference library under
`Rules/offensive-workstation-pentesting/references/cyberstrike/source-library/`
is derived from the official documentation at <https://docs.cyberstrike.io/>.
CyberStrike code, binaries, names, and documentation remain governed by their
upstream license and attribution terms.

The project-level MIT license applies only to original project material.
Third-party files remain governed by their own license and attribution terms.
