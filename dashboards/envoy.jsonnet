// General purpose Envoy dashboard.
//
// Panel inventory is modelled on the upstream Envoy Gateway dashboards
// (envoyproxy/gateway charts/gateway-addons-helm/dashboards), but the queries
// are written from the stat definitions in envoy release/v1.38 rather than
// copied, because our scrape path differs from theirs in two ways:
//
//  1. Envoy's own /stats/prometheus renderer never appends _total to counters
//     (source/server/admin/prometheus_stats.cc writes the tag-extracted name
//     verbatim). Our envoy stats are scraped by an OTel collector sidecar
//     whose prometheus exporter strips and re-adds the suffix, so every
//     counter ends in _total here, including ones upstream queries without it
//     (envoy_cluster_upstream_rq_xx -> envoy_cluster_upstream_rq_xx_total).
//     Counters whose stat name already ended in _total, such as
//     envoy_cluster_upstream_rq_total, round-trip unchanged. Gauges and
//     histogram _bucket/_sum/_count series are untouched.
//
//  2. The collector attaches otel_scope_name and otel_scope_version to every
//     series. otel_scope_version tracks the collector image tag, so it forks
//     every series on an image bump. Every panel therefore aggregates with an
//     explicit sum by (...) and never renders a raw series.
//
// Note also that `container` on these series is the collector sidecar, not
// envoy, so nothing here filters on it.

local cfg = (import 'envoy.libsonnet')._config;

local ds = { type: 'prometheus', uid: '${datasource}' };

local sel = cfg.selector;
local csel = sel + ', envoy_cluster_name=~"$envoy_cluster"';
local hsel = sel + ', envoy_http_conn_manager_prefix=~"$conn_manager"';

// ---------------------------------------------------------------- variables

local datasourceVar = {
  current: {},
  hide: 0,
  includeAll: false,
  label: 'Data source',
  multi: false,
  name: 'datasource',
  options: [],
  query: 'prometheus',
  refresh: 1,
  regex: cfg.datasourceRegex,
  skipUrlSync: false,
  type: 'datasource',
};

local queryVar(name, label, query, multi=false) = {
  current: {},
  datasource: ds,
  definition: query,
  hide: 0,
  includeAll: multi,
  label: label,
  multi: multi,
  name: name,
  options: [],
  query: { query: query, refId: name },
  refresh: 2,
  regex: '',
  skipUrlSync: false,
  sort: 1,
  type: 'query',
};

// envoy_server_live is the anchor for the pickers: it is a core server gauge
// (ALL_SERVER_STATS in source/server/server.h) so it exists on any envoy.
local variables = [
  datasourceVar,
  queryVar('job', 'Job', 'label_values(envoy_server_live, job)'),
  queryVar('namespace', 'Namespace', 'label_values(envoy_server_live{job=~"$job"}, namespace)'),
  queryVar('pod', 'Pod', 'label_values(envoy_server_live{job=~"$job", namespace=~"$namespace"}, pod)', multi=true),
  queryVar(
    'conn_manager',
    'Listener',
    'label_values(envoy_http_downstream_rq_total{job=~"$job", namespace=~"$namespace"}, envoy_http_conn_manager_prefix)',
    multi=true
  ),
  queryVar(
    'envoy_cluster',
    'Upstream cluster',
    'label_values(envoy_cluster_upstream_rq_total{job=~"$job", namespace=~"$namespace"}, envoy_cluster_name)',
    multi=true
  ),
];

// ------------------------------------------------------------------- panels

local refIds = ['A', 'B', 'C', 'D', 'E', 'F'];

local targets(exprs) = [
  {
    datasource: ds,
    expr: exprs[i][0],
    legendFormat: exprs[i][1],
    refId: refIds[i],
  }
  for i in std.range(0, std.length(exprs) - 1)
];

// Fixed colours for states that carry meaning. Status colours are reserved:
// they are never handed out to an ordinary series, and because they are
// pinned by name the colour follows the entity even when a series drops out
// of the result set.
local statusColors(pairs) = [
  {
    matcher: { id: 'byName', options: p[0] },
    properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: p[1] } }],
  }
  for p in pairs
];

local codeClassColors = statusColors([
  ['1xx', 'text'],
  ['2xx', 'green'],
  ['3xx', 'blue'],
  ['4xx', 'orange'],
  ['5xx', 'red'],
]);

local ts(title, exprs, unit='short', overrides=[], description='') = {
  type: 'timeseries',
  title: title,
  [if description != '' then 'description']: description,
  datasource: ds,
  targets: targets(exprs),
  fieldConfig: {
    defaults: {
      unit: unit,
      min: 0,
      color: { mode: 'palette-classic' },
      custom: {
        drawStyle: 'line',
        lineInterpolation: 'linear',
        lineWidth: 2,
        fillOpacity: 0,
        gradientMode: 'none',
        showPoints: 'never',
        pointSize: 8,
        spanNulls: false,
        axisPlacement: 'auto',
        stacking: { group: 'A', mode: 'none' },
      },
    },
    overrides: overrides,
  },
  options: {
    legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
    tooltip: { mode: 'multi', sort: 'desc' },
  },
};

local stat(title, expr, unit='short', description='') = {
  type: 'stat',
  title: title,
  [if description != '' then 'description']: description,
  datasource: ds,
  targets: targets([[expr, '']]),
  fieldConfig: {
    defaults: {
      unit: unit,
      color: { mode: 'thresholds' },
      thresholds: { mode: 'absolute', steps: [{ color: 'text', value: null }] },
    },
    overrides: [],
  },
  options: {
    colorMode: 'none',
    graphMode: 'area',
    justifyMode: 'auto',
    orientation: 'auto',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    textMode: 'auto',
  },
};

local quantiles(metric, selector, by='') =
  local grouping = if by == '' then 'le' else 'le, ' + by;
  local suffix = if by == '' then '' else ' {{' + by + '}}';
  [
    [
      'histogram_quantile(0.%s, sum by (%s) (rate(%s{%s}[$__rate_interval])))' % [q[0], grouping, metric, selector],
      q[1] + suffix,
    ]
    for q in [['50', 'p50'], ['90', 'p90'], ['99', 'p99']]
  ];

// ------------------------------------------------------------------ layout

// Lays sections out top to bottom, each behind a row header, wrapping panels
// at `cols` per line.
local layout(sections) =
  local place(section, y, idBase) =
    local n = std.length(section.panels);
    local w = std.floor(24 / section.cols);
    local lines = std.ceil(n / section.cols);
    {
      next: y + 1 + lines * section.h,
      nextId: idBase + n + 1,
      panels: [{
        type: 'row',
        title: section.title,
        collapsed: false,
        panels: [],
        gridPos: { h: 1, w: 24, x: 0, y: y },
      }] + [
        section.panels[i] {
          id: idBase + i + 1,
          gridPos: {
            h: section.h,
            w: w,
            x: (i % section.cols) * w,
            y: y + 1 + std.floor(i / section.cols) * section.h,
          },
        }
        for i in std.range(0, n - 1)
      ],
    };

  std.foldl(
    function(acc, section)
      local r = place(section, acc.y, acc.id);
      { y: r.next, id: r.nextId, panels: acc.panels + r.panels },
    sections,
    { y: 0, id: 0, panels: [] }
  ).panels;

// ---------------------------------------------------------------- sections

local overview = {
  title: 'Overview',
  cols: 6,
  h: 4,
  panels: [
    stat('Live servers', 'sum(envoy_server_live{%s})' % sel, 'short', 'Envoy processes reporting themselves live.'),
    stat('Shortest uptime', 'min(envoy_server_uptime{%s})' % sel, 's', 'Lowest uptime across the selected pods. A drop means a restart.'),
    stat('Memory allocated', 'sum(envoy_server_memory_allocated{%s})' % sel, 'bytes'),
    stat('Heap size', 'sum(envoy_server_memory_heap_size{%s})' % sel, 'bytes'),
    stat('Active connections', 'sum(envoy_http_downstream_cx_active{%s})' % hsel, 'short'),
    stat('Active requests', 'sum(envoy_http_downstream_rq_active{%s})' % hsel, 'short'),
  ],
};

local downstream = {
  title: 'Downstream (client to Envoy)',
  cols: 2,
  h: 8,
  panels: [
    ts(
      'Request rate by response class',
      [['sum by (envoy_response_code_class) (rate(envoy_http_downstream_rq_xx_total{%s}[$__rate_interval]))' % hsel, '{{envoy_response_code_class}}xx']],
      'reqps',
      codeClassColors
    ),
    ts(
      'Error ratio',
      [[
        'sum(rate(envoy_http_downstream_rq_xx_total{%s, envoy_response_code_class="5"}[$__rate_interval]))' % hsel +
        ' / clamp_min(sum(rate(envoy_http_downstream_rq_total{%s}[$__rate_interval])), 1e-9)' % hsel,
        '5xx',
      ]],
      'percentunit',
      statusColors([['5xx', 'red']]),
      'Downstream 5xx as a fraction of all downstream requests.'
    ),
    ts('Request latency', quantiles('envoy_http_downstream_rq_time_bucket', hsel), 'ms'),
    ts(
      'Active connections and requests',
      [
        ['sum(envoy_http_downstream_cx_active{%s})' % hsel, 'connections'],
        ['sum(envoy_http_downstream_rq_active{%s})' % hsel, 'requests'],
      ],
      'short'
    ),
    ts(
      'Connection rate',
      [
        ['sum(rate(envoy_http_downstream_cx_total{%s}[$__rate_interval]))' % hsel, 'accepted'],
        ['sum(rate(envoy_http_downstream_cx_destroy_total{%s}[$__rate_interval]))' % hsel, 'destroyed'],
      ],
      'cps'
    ),
    ts(
      'Request faults',
      [
        ['sum(rate(envoy_http_downstream_rq_timeout_total{%s}[$__rate_interval]))' % hsel, 'timeout'],
        ['sum(rate(envoy_http_downstream_rq_rx_reset_total{%s}[$__rate_interval]))' % hsel, 'rx reset'],
        ['sum(rate(envoy_http_downstream_rq_tx_reset_total{%s}[$__rate_interval]))' % hsel, 'tx reset'],
        ['sum(rate(envoy_http_downstream_cx_protocol_error_total{%s}[$__rate_interval]))' % hsel, 'protocol error'],
        ['sum(rate(envoy_http_downstream_rq_too_large_total{%s}[$__rate_interval]))' % hsel, 'request too large'],
      ],
      'reqps'
    ),
  ],
};

// These filters are optional in envoy, so these panels stay empty on a proxy
// that does not configure them.
local authnz = {
  title: 'Authentication and authorization',
  cols: 3,
  h: 8,
  panels: [
    ts(
      'JWT authentication',
      [
        ['sum(rate(envoy_http_jwt_authn_allowed_total{%s}[$__rate_interval]))' % sel, 'allowed'],
        ['sum(rate(envoy_http_jwt_authn_denied_total{%s}[$__rate_interval]))' % sel, 'denied'],
      ],
      'reqps',
      statusColors([['allowed', 'green'], ['denied', 'red']]),
      'jwt_authn filter. denied is the 401 path.'
    ),
    ts(
      'JWKS fetches',
      [
        ['sum(rate(envoy_http_jwt_authn_jwks_fetch_success_total{%s}[$__rate_interval]))' % sel, 'success'],
        ['sum(rate(envoy_http_jwt_authn_jwks_fetch_failed_total{%s}[$__rate_interval]))' % sel, 'failed'],
      ],
      'reqps',
      statusColors([['success', 'green'], ['failed', 'red']]),
      'Health of the remote JWKS dependency. Sustained failures mean tokens stop verifying once the cache expires.'
    ),
    ts(
      'JWT cache',
      [
        ['sum(rate(envoy_http_jwt_authn_jwt_cache_hit_total{%s}[$__rate_interval]))' % sel, 'hit'],
        ['sum(rate(envoy_http_jwt_authn_jwt_cache_miss_total{%s}[$__rate_interval]))' % sel, 'miss'],
      ],
      'reqps'
    ),
    ts(
      'RBAC decisions',
      [
        ['sum(rate(envoy_http_rbac_allowed_total{%s}[$__rate_interval]))' % sel, 'allowed'],
        ['sum(rate(envoy_http_rbac_denied_total{%s}[$__rate_interval]))' % sel, 'denied'],
      ],
      'reqps',
      statusColors([['allowed', 'green'], ['denied', 'red']]),
      'rbac filter. denied is the 403 path.'
    ),
    ts(
      'RBAC shadow decisions',
      [
        ['sum(rate(envoy_http_rbac_shadow_allowed_total{%s}[$__rate_interval]))' % sel, 'shadow allowed'],
        ['sum(rate(envoy_http_rbac_shadow_denied_total{%s}[$__rate_interval]))' % sel, 'shadow denied'],
      ],
      'reqps',
      [],
      'Decisions a shadow policy would have made. Use this to see the effect of a policy before enforcing it.'
    ),
    ts(
      'Admission control',
      [
        ['sum(rate(envoy_http_admission_control_rq_success_total{%s}[$__rate_interval]))' % sel, 'success'],
        ['sum(rate(envoy_http_admission_control_rq_failure_total{%s}[$__rate_interval]))' % sel, 'failure'],
        ['sum(rate(envoy_http_admission_control_rq_rejected_total{%s}[$__rate_interval]))' % sel, 'rejected'],
      ],
      'reqps',
      statusColors([['success', 'green'], ['failure', 'orange'], ['rejected', 'red']]),
      'rejected is load shed by the filter itself, not by an upstream.'
    ),
  ],
};

local upstream = {
  title: 'Upstream (Envoy to backend)',
  cols: 2,
  h: 8,
  panels: [
    ts(
      'Request rate by cluster',
      [['sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{%s}[$__rate_interval]))' % csel, '{{envoy_cluster_name}}']],
      'reqps'
    ),
    ts(
      '5xx rate by cluster',
      [['sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_xx_total{%s, envoy_response_code_class="5"}[$__rate_interval]))' % csel, '{{envoy_cluster_name}}']],
      'reqps'
    ),
    ts(
      'Response class, all clusters',
      [['sum by (envoy_response_code_class) (rate(envoy_cluster_upstream_rq_xx_total{%s}[$__rate_interval]))' % csel, '{{envoy_response_code_class}}xx']],
      'reqps',
      codeClassColors
    ),
    ts(
      'p99 latency by cluster',
      [[
        'histogram_quantile(0.99, sum by (le, envoy_cluster_name) (rate(envoy_cluster_upstream_rq_time_bucket{%s}[$__rate_interval])))' % csel,
        '{{envoy_cluster_name}}',
      ]],
      'ms'
    ),
    ts(
      'Active connections by cluster',
      [['sum by (envoy_cluster_name) (envoy_cluster_upstream_cx_active{%s})' % csel, '{{envoy_cluster_name}}']],
      'short'
    ),
    ts(
      'Connection failures',
      [
        ['sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_cx_connect_fail_total{%s}[$__rate_interval]))' % csel, 'connect fail {{envoy_cluster_name}}'],
        ['sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_cx_connect_timeout_total{%s}[$__rate_interval]))' % csel, 'connect timeout {{envoy_cluster_name}}'],
      ],
      'cps'
    ),
    ts(
      'Retries and rejections',
      [
        ['sum(rate(envoy_cluster_upstream_rq_retry_total{%s}[$__rate_interval]))' % csel, 'retry'],
        ['sum(rate(envoy_cluster_upstream_rq_retry_success_total{%s}[$__rate_interval]))' % csel, 'retry success'],
        ['sum(rate(envoy_cluster_upstream_rq_timeout_total{%s}[$__rate_interval]))' % csel, 'timeout'],
        ['sum(rate(envoy_cluster_upstream_rq_pending_overflow_total{%s}[$__rate_interval]))' % csel, 'pending overflow'],
        ['sum(rate(envoy_cluster_upstream_rq_pending_failure_eject_total{%s}[$__rate_interval]))' % csel, 'pending failure eject'],
      ],
      'reqps'
    ),
    ts(
      'Endpoint health',
      [
        ['sum by (envoy_cluster_name) (envoy_cluster_membership_healthy{%s})' % csel, 'healthy {{envoy_cluster_name}}'],
        [
          'sum by (envoy_cluster_name) (envoy_cluster_membership_total{%s}) - sum by (envoy_cluster_name) (envoy_cluster_membership_healthy{%s})' % [csel, csel],
          'unhealthy {{envoy_cluster_name}}',
        ],
      ],
      'short'
    ),
  ],
};

local saturation = {
  title: 'Saturation',
  cols: 3,
  h: 8,
  panels: [
    ts(
      'Circuit breakers open',
      [
        ['sum by (envoy_cluster_name) (envoy_cluster_circuit_breakers_default_rq_open{%s})' % csel, 'rq {{envoy_cluster_name}}'],
        ['sum by (envoy_cluster_name) (envoy_cluster_circuit_breakers_default_cx_open{%s})' % csel, 'cx {{envoy_cluster_name}}'],
      ],
      'short',
      [],
      'Non-zero means the cluster is shedding load at its configured limit.'
    ),
    // Overload manager stats are named from the envoy config
    // (overload.<action>.active, overload.<resource>.pressure in
    // source/server/overload_manager_impl.cc), so the metric names below only
    // exist on a proxy that configures those particular actions and monitors.
    ts(
      'Overload manager',
      [
        ['sum(envoy_overload_envoy_overload_actions_shrink_heap_active{%s})' % sel, 'shrink heap active'],
        ['sum(envoy_overload_envoy_overload_actions_stop_accepting_requests_active{%s})' % sel, 'stop accepting requests active'],
        ['max(envoy_overload_envoy_resource_monitors_fixed_heap_pressure{%s})' % sel, 'fixed heap pressure'],
      ],
      'short',
      statusColors([['stop accepting requests active', 'red'], ['shrink heap active', 'orange']]),
      'Action names come from the envoy config, so these series only exist where those actions are configured.'
    ),
    ts(
      'Memory',
      [
        ['sum(envoy_server_memory_allocated{%s})' % sel, 'allocated'],
        ['sum(envoy_server_memory_heap_size{%s})' % sel, 'heap size'],
        ['sum(envoy_server_memory_physical_size{%s})' % sel, 'physical size'],
      ],
      'bytes'
    ),
  ],
};

// ------------------------------------------------------------------- output

local dashboard = {
  uid: cfg.uid,
  title: cfg.title,
  tags: cfg.tags,
  timezone: 'UTC',
  editable: true,
  graphTooltip: 1,
  schemaVersion: 39,
  refresh: cfg.refresh,
  time: { from: 'now-6h', to: 'now' },
  templating: { list: variables },
  annotations: { list: [] },
  links: [],
  panels: layout([overview, downstream, authnz, upstream, saturation]),
};

{
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-' + cfg.uid,
    labels+: { grafana_dashboard: 'true' },
    annotations+: {
      'grafana-folder': cfg.folder,
    },
  },
  data: {
    'envoy-overview.json': std.manifestJsonEx(dashboard, '  '),
  },
}
