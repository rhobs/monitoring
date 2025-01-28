local utils = (import 'lib.libsonnet');
local alertmanagerConfig = (import 'alertmanager.libsonnet');
local alertmanagerAlerts = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/mixin.libsonnet') + alertmanagerConfig;
utils.renderAlerts('alertmanager', std.extVar('environment'), alertmanagerConfig._config.dashboardID, alertmanagerAlerts)

