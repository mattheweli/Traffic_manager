# Traffic_manager 2.0.0

Baseline: `1c5148ef576b2c97fb22f81471a0ace3eae6ea6f`.

- Stable 2.0.0 responsive multi-interface dashboard with aligned table headers/body, full dates in Top 10 Days, paired traffic doughnuts/values and common theme/refresh controls.
- Resolve interface selection from explicit arguments/existing configuration instead of publishing Unknown; validate vnStat JSON and retain the last good export when vnStat fails. Missing data is distinguished from a disabled daemon.
- Preserve vnStat databases, custom interface jobs and existing exports. Uniform grouped values/decimal separators in quotas, rates, totals and tooltips.
- External dashboard settings survive updates. Full-width layouts, shared navigation and version/copyright footer replace the alpha banner.

## Installation and compatibility

Install/update through the complete KeenTool 2.0.0 suite asset. Component archives require the coordinated shared runtime; do not replace isolated scripts over older installations. Existing settings, credentials, databases and upgrade schedules are preserved. Read the suite docs/INSTALL.md and SECURITY.md.

## Known feed limitation

IPdeny IPv6 KP may return HTTP 404; incomplete candidates retain the installed GeoBlock6 list. Cached installation time is not source freshness. This is reported explicitly, not silently bypassed.

## Validation

See suite docs/VALIDATION.md for isolated regression results and the live-router acceptance steps that remain before publication. This prepared release is a draft; no router reboot or public deployment is claimed.
