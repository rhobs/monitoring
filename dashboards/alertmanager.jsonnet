local alertmanager = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/dashboards/overview.libsonnet');
local defaultConfig = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/config.libsonnet');
local mixin = alertmanager {
  _config+:: defaultConfig._config {
    alertmanagerClusterLabels: 'namespace,job',
    alertmanagerNameLabels: 'pod',
    alertmanagerCriticalIntegrationsRegEx: 'slack|pagerduty|email|webhook',
    alertmanagerSelector: 'job="alertmanager"',
  },
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
