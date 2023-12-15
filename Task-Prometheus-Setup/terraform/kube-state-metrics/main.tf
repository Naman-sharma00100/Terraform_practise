provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_namespace" "kube_system" {
  metadata {
    name = "kube-system"
  }
}

resource "kubernetes_service" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = "2.3.0"
    }
  }

  spec {
    cluster_ip = "None"

    port {
      name       = "http-metrics"
      port       = 8080
      target_port = "http-metrics"
    }

    port {
      name       = "telemetry"
      port       = 8081
      target_port = "telemetry"
    }

    selector = {
      "app.kubernetes.io/name" = "kube-state-metrics"
    }
  }
}

resource "kubernetes_service_account" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = "2.3.0"
    }
  }
}

resource "kubernetes_cluster_role" "kube_state_metrics" {
  metadata {
    name = "kube-state-metrics"
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = "2.3.0"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets", "nodes", "pods", "services", "resourcequotas", "replicationcontrollers", "limitranges", "persistentvolumeclaims", "persistentvolumes", "namespaces", "endpoints"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "daemonsets", "deployments", "replicasets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["list", "watch"]
  }

  # Add other rules as needed
}

resource "kubernetes_cluster_role_binding" "kube_state_metrics" {
  metadata {
    name = "kube-state-metrics"
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = "2.3.0"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kube_state_metrics.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kube_state_metrics.metadata[0].name
    namespace = "kube-system"
  }
}


resource "kubernetes_deployment" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = "2.3.0"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "kube-state-metrics"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/component" = "exporter"
          "app.kubernetes.io/name"      = "kube-state-metrics"
          "app.kubernetes.io/version"   = "2.3.0"
        }
      }

      spec {
        automount_service_account_token = true

        container {
          name  = "kube-state-metrics"
          image = "k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.3.0"

          port {
            container_port = 8080
            name           = "http-metrics"
          }

          port {
            container_port = 8081
            name           = "telemetry"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem = true
            run_as_user               = 65534
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        service_account_name = kubernetes_service_account.kube_state_metrics.metadata[0].name
      }
    }
  }
}
