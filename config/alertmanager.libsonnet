local alertmanager_mixin = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/config.libsonnet');
local selector = std.extVar('selector');
alertmanager_mixin {
  _config+:: {
    alertmanagerClusterLabels: 'namespace,job',
    alertmanagerNameLabels: 'pod',
    alertmanagerCriticalIntegrationsRegEx: 'slack|pagerduty|email|webhook',
    alertmanagerSelector: selector,
    dashboardID: 'alertmanager-overview',
  },
}
