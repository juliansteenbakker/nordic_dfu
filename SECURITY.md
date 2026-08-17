# Security Policy

## Supported Versions

Only the latest released version of `nordic_dfu` is supported with security updates.

## Scope

This plugin is a Flutter wrapper around Nordic Semiconductor's official DFU
libraries. Vulnerabilities in the DFU protocol itself, in the bootloader, or in the
signature verification of a firmware package should be reported to the relevant
upstream project instead:

* [Android DFU Library](https://github.com/NordicSemiconductor/Android-DFU-Library/security)
* [iOS DFU Library](https://github.com/NordicSemiconductor/IOS-DFU-Library/security)

Issues in this repository's Dart API or in its Android/Apple platform channel code
are in scope here.

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public GitHub issue. Instead, report it privately using [GitHub's private vulnerability reporting](https://github.com/juliansteenbakker/nordic_dfu/security/advisories/new).

Please include as much detail as possible (affected platform, reproduction steps, potential impact) so the report can be triaged quickly.
