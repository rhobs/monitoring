local alertmanager = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/dashboards/overview.libsonnet');
local alertmanagerConfig = (import 'alertmanager.libsonnet');

local mixin = alertmanager {
  _config+:: alertmanagerConfig._config,

  // Override the dashboard to set a custom UID
  grafanaDashboards+:: {
    'alertmanager-overview.json'+: {
      uid: 'rhobs-alertmanager-overview',  // Set your custom UID here
    },
  },
};

{
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-rhobs-alertmanager-overview',
    labels+: { grafana_dashboard: 'true' },
    annotations+: {
      'grafana-folder': '/grafana-dashboard-definitions/RHOBS',
    },
  },
  data: {
    'alertmanager-overview.json': std.manifestJsonEx(mixin.grafanaDashboards['alertmanager-overview.json'], '  '),
  },
}
