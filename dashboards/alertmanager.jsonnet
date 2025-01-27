local alertmanager = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/dashboards/overview.libsonnet');
local alertmanagerConfig = (import 'alertmanager.libsonnet');

local mixin = alertmanager {
  _config+:: alertmanagerConfig._config,
};

{
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-observatorium-alertmanager-overview',
    labels+: { grafana_dashboard: 'true' },
    annotations+: {
      'grafana-folder': '/grafana-dashboard-definitions/Observatorium',
    },
  },
  data: {
    'alertmanager-overview.json': std.manifestJsonEx(mixin.grafanaDashboards['alertmanager-overview.json'], '  '),
  },
}
