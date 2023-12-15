provider "kubernetes" {
  config_path    = "~/.kube/config"  # Update with your Minikube config path
  config_context = "minikube"        # Update with your Minikube context
}


resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "alertmanager-config"
    namespace = "monitoring"
  }

  data = {
    "config.yml" = file("${path.module}/AlertManagerConfigmap.yaml")
  }
}

resource "kubernetes_config_map" "alertmanager_templates" {
  metadata {
    name      = "alertmanager-templates"
    namespace = "monitoring"
  }

  data = {
    "default.tmpl" = file("${path.module}/AlertTemplateConfigmap.yaml")
  }
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
              cpu    = 1
              memory = "1Gi"
            }
          }

          volume_mount {
            mount_path = "/etc/alertmanager"
            name       = "config-volume"
          }

          volume_mount {
            mount_path = "/etc/alertmanager-templates"
            name       = "templates-volume"
          }

          volume_mount {
            mount_path = "/alertmanager"
            name       = "alertmanager"
          }
        }

        volume{
          config_map {
            name = "alertmanager-config"
          }
          name = "config-volume"
        }

        volume {
          config_map {
            name = "alertmanager-templates"
          }
          name = "templates-volume"
        }

        volume {
          empty_dir {}
          name = "alertmanager"
        }
      }
    }
  }
}

