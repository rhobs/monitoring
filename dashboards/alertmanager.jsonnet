local alertmanager = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/dashboards/overview.libsonnet');
local alertmanagerConfig = (import 'alertmanager.libsonnet');

local mixin = alertmanager {
  _config+:: alertmanagerConfig._config,

  // Override the dashboard to set a custom UID
  grafanaDashboards+:: {
    'alertmanager-overview.json'+: {
      uid: 'rhobs-alertmanager-overview',
      // Add the templating override
      templating+: {
        list: std.map(
          function(template)
            if template.name == 'datasource' then
              // Add the regex filter to limit data sources
              template { regex: 'telemeter-prod-01-prometheus|app-sre-stage-01-prometheus' }
            else
              template,
          super.list
        ),
      },

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
