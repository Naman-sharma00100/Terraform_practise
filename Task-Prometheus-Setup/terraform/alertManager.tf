provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}
resource "kubernetes_service" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = "monitoring"
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9093"
    }
  }

  spec {
    selector = {
      app = "alertmanager"
    }

    type = "NodePort"

    port {
      port        = 9093
      target_port = 9093
      node_port   = 31000
    }
  }
}


resource "kubernetes_deployment" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = "monitoring"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "alertmanager"
      }
    }

    template {
      metadata {
        name = "alertmanager"
        labels = {
          app = "alertmanager"
        }
      }

      spec {
        container {
          name  = "alertmanager"
          image = "prom/alertmanager:latest"

          args = [
            "--config.file=/etc/alertmanager/config.yml",
            "--storage.path=/alertmanager",
          ]

          port {
            name          = "alertmanager"
            container_port = 9093
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "500M"
            }
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/alertmanager"
          }

          volume_mount {
            name       = "templates-volume"
            mount_path = "/etc/alertmanager-templates"
          }

          volume_mount {
            name       = "alertmanager"
            mount_path = "/alertmanager"
          }
        }

        volume {
          name = "config-volume"

          config_map {
            name = "./alertmanager-config.yml"
          }
        }

        volume {
          name = "templates-volume"

          config_map {
            name = "alertmanager-templates"
          }
        }

        volume {
          name = "alertmanager"

          empty_dir {}
        }
      }
    }
  }
}
