{
  _config+:: {
    uid: 'rhobs-envoy-overview',
    title: 'Envoy / Overview',
    folder: '/grafana-dashboard-definitions/RHOBS',
    tags: ['rhobs', 'envoy'],
    refresh: '1m',

    // Datasources this dashboard can be pointed at. Envoy stats are scraped
    // into the cluster-local Prometheus, so these are the <cluster>-prometheus
    // datasources rather than the RHOBS tenant ones.
    datasourceRegex: '/-prometheus$/',

    // Counters reach Prometheus through the OTel collector sidecar, whose
    // prometheus exporter re-appends _total to any counter that did not
    // already end in it. Envoy itself never adds the suffix. Gauges and
    // histograms are untouched. See the comment in dashboards/envoy.jsonnet.
    //
    // Selector applied to every query. pod is kept so a single misbehaving
    // replica can be isolated.
    selector: 'job=~"$job", namespace=~"$namespace", pod=~"$pod"',
  },
}
