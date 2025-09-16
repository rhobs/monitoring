local dashboards = (import 'dashboards.libsonnet');

{
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-rhobs-loki-writes',
    labels+: { grafana_dashboard: 'true' },
    annotations+: {
      'grafana-folder': '/grafana-dashboard-definitions/RHOBS',
    },
  },
  data: {
    'dashboard.json': dashboards['writes.json'],
  },
}
