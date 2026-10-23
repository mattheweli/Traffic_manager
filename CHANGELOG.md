# Traffic_manager stable changelog

Baseline: `1c5148ef576b2c97fb22f81471a0ace3eae6ea6f`.

- Stable 2.0.0 responsive multi-interface dashboard with aligned table headers/body, full dates in Top 10 Days, paired traffic doughnuts/values and common theme/refresh controls.
- Resolve interface selection from explicit arguments/existing configuration instead of publishing Unknown; validate vnStat JSON and retain the last good export when vnStat fails. Missing data is distinguished from a disabled daemon.
- Preserve vnStat databases, custom interface jobs and existing exports. Uniform grouped values/decimal separators in quotas, rates, totals and tooltips.
- External dashboard settings survive updates. Full-width layouts, shared navigation and version/copyright footer replace the alpha banner.
