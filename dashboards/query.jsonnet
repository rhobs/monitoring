local config = (import 'query.libsonnet');

local thanos =
  (import 'github.com/thanos-io/thanos/mixin/dashboards/query.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/overview.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/defaults.libsonnet');




{
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-rhobs-thanos-query-overview',
    labels+: { grafana_dashboard: 'true' },
    annotations+: {
      'grafana-folder': '/grafana-dashboard-definitions/RHOBS',
    },
  },
  data: {
    //todo
  },
}
