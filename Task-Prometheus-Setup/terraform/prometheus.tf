resource "kubernetes_config_map" "prometheus-config" {
  metadata {
    name      = "prometheus-config"
    namespace = "monitoring"
  }

  data = {
    "prometheus.yml" = file("./config-map.yaml")
  }
}

