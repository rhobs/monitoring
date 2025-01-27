local appSREOverwrites(environment, dashboardID) = {
  local dashboardDatasource = function(environment) {
    datasource:
      if
        environment == 'stage' then 'app-sre-stage-01-prometheus'
      else if
        environment == 'production' then 'telemeter-prod-01-prometheus'
      else error 'no datasource for environment %s' % environment,
  },

  local setSeverity = function(label, environment) {
    label:
      if
        label == 'critical' then
        if
          environment == 'stage' then 'high'
        else label
      else if
        label == 'warning' then 'medium'
      else 'high',
  },

  local pruneUnsupportedLabels = function(labels) {
    // Prune selector label because not allowed by AppSRE
    // If you are pruning labels, ensure the ONLY_IN_BASE_ is prefixed
    // Pruned labels will not exist on generated queries.
    labels: std.prune(labels {
      group: null,  // Only exists for logs.
      ONLY_IN_BASE_client: null,
      ONLY_IN_BASE_container: null,
      ONLY_IN_BASE_group: null,
      ONLY_IN_BASE_code: null,
    }),
  },

  groups: [
    g {
      rules: [
        if std.objectHas(r, 'alert') then
          r {
            annotations+:
              {
                // Message is a required field. Upstream thanos-mixin doesn't have it.
                message: if std.objectHasAll(self, 'description') then self.description else r.annotations.message,
              } +
              if std.startsWith(g.name, 'telemeter') then
                {
                  runbook: 'https://github.com/rhobs/configuration/blob/main/docs/sop/telemeter.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/telemeter?orgId=1&refresh=1m&var-datasource={{$externalLabels.cluster}}-prometheus' % [
                    dashboardID(g.name, environment).id,
                  ],
                }
              else
                {
                  runbook: 'https://github.com/rhobs/configuration/blob/main/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-datasource={{$externalLabels.cluster}}-prometheus&var-namespace={{$labels.namespace}}&var-job=All&var-pod=All&var-interval=5m' % [
                    dashboardID,
                    g.name,
                  ],
                },
            labels: pruneUnsupportedLabels(r.labels {
              service: 'telemeter',
              severity: setSeverity(r.labels.severity, environment).label,
            }).labels,
          } else r {
          labels: pruneUnsupportedLabels(r.labels).labels,
        }
        for r in super.rules
      ],
    }
    for g in super.groups
  ],
} + {
  groups: [
    group {
      rules: std.filter(
        function(rule) !(
          std.objectHas(rule, 'alert') && (
            // Using multi-burnrate SLO alerts for these.
            rule.alert == 'ThanosQueryHttpRequestQueryRangeErrorRateHigh' ||
            rule.alert == 'ThanosQueryRangeLatencyHigh' ||
            rule.alert == 'ThanosStoreSeriesGateLatencyHigh' ||
            // These components arent' deployed.
            rule.alert == 'ThanosSidecarIsDown' ||
            rule.alert == 'ThanosBucketReplicateIsDown' ||
            // Skipping ThanosQueryOverload alert due to topology of
            // Queriers with concurrency set to 1, which very frequently
            // fires this alert.
            rule.alert == 'ThanosQueryOverload'
          )
        ),
        super.rules,
      ),
    }
    for group in super.groups
  ],
};

{
  renderAlerts(name, environment, dashboardID, mixin):: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: name,
      labels: {
        prometheus: 'app-sre',
        role: 'alert-rules',
      },
    },

    spec: mixin {
      prometheusAlerts+:: appSREOverwrites(environment, dashboardID),
    }.prometheusAlerts,
  },
}
