provider "kubernetes" {
  config_path    = "~/.kube/config"  
  config_context = "minikube"       
}

locals {
  prometheus_config_content = file("./config-map.yaml")
}

resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-server-conf"
    namespace = "monitoring"
    labels = {
      name = "prometheus-server-conf"
    }
  }

  data = {
    "prometheus-config.yaml" = local.prometheus_config_content
  }
}


resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs            = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "monitoring"
  }
}



resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus-deployment"
    namespace = "monitoring"
    labels = {
      app = "prometheus-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus-server"
        }
      }

      spec {
        container {
          name  = "prometheus"
          image = "prom/prometheus"

          args = [
            "--storage.tsdb.retention.time=12h",
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus/",
          ]

          port {
            container_port = 9090
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "500M"
            }

            limits = {
              cpu    = 1
              memory = "1Gi"
            }
          }

          volume_mount {
            name       = "prometheus-config-volume"
            mount_path = "/etc/prometheus/"
          }

          volume_mount {
            name       = "prometheus-storage-volume"
            mount_path = "/prometheus/"
          }
        }

        volume {
          name = "prometheus-config-volume"

          config_map {
            name = "prometheus-server-conf"
          }
        }

        volume {
          name = "prometheus-storage-volume"

          empty_dir {}
        }
      }
    }
  }
}


resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus-service"
    namespace = "monitoring"

    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9090"
    }
  }

  spec {
    selector = {
      app = "prometheus-server"
    }

    type = "NodePort"

    port {
      port        = 8080
      target_port = 9090
      node_port   = 30000
    }
  }
}