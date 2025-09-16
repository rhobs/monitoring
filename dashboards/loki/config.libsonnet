local utils = (import 'github.com/grafana/jsonnet-libs/mixin-utils/utils.libsonnet');

{
  loki: {
    local withDatasource = function(ds) ds + (
      if ds.name == 'datasource' then {
        query: 'prometheus',
        current: {
          selected: true,
          text: 'rhobsi01uw2-prometheus',
          value: 'rhobsi01uw2-prometheus',
        },
      } else {}
    ),

    local withNamespace = function(ns) ns + (
      if ns.label == 'namespace' then {
        datasource: '${datasource}',
        current: {
          selected: false,
          text: 'rhobs-int',
          value: 'rhobs-int',
        },
        definition: 'label_values(loki_build_info, namespace)',
        query: 'label_values(loki_build_info, namespace)',
      } else {}
    ),

    local defaultLokiTags = function(t)
      std.uniq(t + ['logging', 'loki-mixin']),

    local replaceMatchers = function(replacements)
      function(p) p {
        targets: [
          t {
            expr: std.foldl(function(x, rp) std.strReplace(x, rp.from, rp.to), replacements, t.expr),
          }
          for t in p.targets
          if std.objectHas(p, 'targets')
        ],
      },

    // dropPanels removes unnecessary panels based on title or a function.
    local dropPanels = function(panels, dropList, fn)
      [
        p
        for p in panels
        if !std.member(dropList, p.title) && fn(p)
      ],

    // mapPanels applies recursively a set of functions over all panels.
    // Note: A Grafana dashboard panel can include other panels.
    // Example: Replace job label in expression and add axis units for all panels.
    local mapPanels = function(funcs, panels)
      [
        // Transform the current panel by applying all transformer funcs.
        // Keep the last version after foldl ends.
        std.foldl(function(agg, fn) fn(agg), funcs, p) + (
          // Recursively apply all transformer functions to any
          // children panels.
          if std.objectHas(p, 'panels') then {
            panels: mapPanels(funcs, p.panels),
          } else {}
        )
        for p in panels
      ],

    // mapTemplateParameters applies a static list of transformer functions to
    // all dashboard template parameters. The static list includes:
    // - cluster-prometheus as datasource based on environment.
    local mapTemplateParameters = function(ls)
      [
        std.foldl(function(x, fn) fn(x), [withDatasource, withNamespace], item)
        for item in ls
        if item.name != 'cluster'
      ],

    grafanaDashboards+: {
      'loki-retention.json'+: {
        local replacements = [
          { from: 'cluster=~"$cluster",', to: '' },
          { from: 'container="compactor"', to: 'container=~".+-compactor"' },
          { from: 'job=~"($namespace)/compactor"', to: 'namespace="$namespace", job=~".+-compactor-http"' },
        ],
        uid: 'rhobs-lokistack-retention',
        title: 'LokiStack / Retention',
        tags: defaultLokiTags(super.tags),
        refresh: '5m',
        rows: [
          r {
            panels: mapPanels([replaceMatchers(replacements)], r.panels),
          }
          for r in super.rows
        ],
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
      'loki-chunks.json'+: {
        uid: 'rhobs-lokistack-chunks',
        title: 'LokiStack / Chunks',
        tags: defaultLokiTags(super.tags),
        refresh: '5m',
        showMultiCluster:: false,
        namespaceQuery:: 'label_values(loki_build_info, namespace)',
        namespaceType:: 'query',
        labelsSelector:: 'namespace="$namespace", job=~".+-ingester-http"',
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
      'loki-reads.json'+: {
        // We drop both BigTable and BlotDB dashboards as they have been
        // replaced by the Index dashboards
        local dropList = ['BigTable', 'Ingester - Zone Aware', 'BoltDB Index', 'Bloom Gateway'],


        uid: 'rhobs-lokistack-reads',
        title: 'LokiStack / Reads',
        tags: defaultLokiTags(super.tags),
        refresh: '5m',
        showMultiCluster:: false,
        namespaceQuery:: 'label_values(loki_build_info, namespace)',
        namespaceType:: 'query',
        matchers:: {
          cortexgateway:: [],
          bloomGateway:: [],
          queryFrontend:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-query-frontend-http'),
          ],
          querier:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-querier-http'),
          ],
          ingester:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-ingester-http'),
          ],
          ingesterZoneAware:: [],
          indexGateway:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-index-gateway-http'),
          ],
          querierOrIndexGateway:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-index-gateway-http'),
          ],
        },
        rows: [
          r {
            panels: r.panels,
          }
          for r in dropPanels(super.rows, dropList, function(p) true)
        ],
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
      'loki-writes.json'+: {
        local dropList = ['Ingester - Zone Aware', 'BoltDB Index'],
        uid: 'rhobs-lokistack-writes',
        title: 'LokiStack / Writes',
        tags: defaultLokiTags(super.tags),
        refresh: '5m',
        showMultiCluster:: false,
        namespaceQuery:: 'label_values(loki_build_info, namespace)',
        namespaceType:: 'query',
        matchers:: {
          cortexgateway:: [],
          distributor:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-distributor-http'),
          ],
          ingester:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-ingester-http'),
          ],
          ingester_zone:: [],
          any_ingester:: [
            utils.selector.eq('namespace', '$namespace'),
            utils.selector.re('job', '.+-ingester-http'),
          ],
        },
        rows: [
          r {
            panels: r.panels,
          }
          for r in dropPanels(super.rows, dropList, function(p) true)
        ],
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
    },
  },
}
