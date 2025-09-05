local cfg = (import 'config.libsonnet');
local loki = (import 'github.com/grafana/loki/production/loki-mixin/mixin.libsonnet') + cfg.loki;

{
  'chunks.json': std.manifestJsonEx(loki.grafanaDashboards['loki-chunks.json'], '  '),
  'reads.json': std.manifestJsonEx(loki.grafanaDashboards['loki-reads.json'], '  '),
  'writes.json': std.manifestJsonEx(loki.grafanaDashboards['loki-writes.json'], '  '),
  'retention.json': std.manifestJsonEx(loki.grafanaDashboards['loki-retention.json'], '  '),
}
