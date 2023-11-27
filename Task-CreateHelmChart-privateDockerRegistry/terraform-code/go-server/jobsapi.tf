provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}


resource "kubernetes_secret" "my_tls_secret_server" {
  metadata {
    name = "my-tls-secret-server"
  }

  data = {
    "tls.crt" = file("../naman.training.app.crt")
    "tls.key" = file("../naman.training.app-key.pem")
  }
}


resource "kubernetes_service_account" "go_server_service_account" {
  metadata {
    name = "go-server-service-account"
  }
}

resource "kubernetes_role" "go_server_role" {
  metadata {
    namespace = "default"
    name      = "go-server-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "go_server_role_binding" {
  metadata {
    namespace = "default"
    name      = "go-server-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.go_server_service_account.metadata[0].name
    namespace = "default"
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role.go_server_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "kubernetes_deployment" "go_server" {
  metadata {
    name = "go-server"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "go-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "go-server"
        }
      }

      spec {
        container {
          name  = "go-server"
          image = "naman.training.registry/go-job-server:4.0"

          port {
            container_port = 8080
          }
        }

        service_account_name = kubernetes_service_account.go_server_service_account.metadata[0].name
      }
    }
  }
}

resource "kubernetes_service" "go_server_service" {
  metadata {
    name = "go-server-service"
  }

  spec {
    selector = {
      app = "go-server"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "go_server_ingress" {
  metadata {
    name = "go-server-ingress"
  }
  spec {
    rule {
      host = "naman.training.app"

      http {
        path {
          path = "/"

          backend {
            service {
              name = kubernetes_service.go_server_service.metadata[0].name
              port {
                number = kubernetes_service.go_server_service.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
    tls {
      hosts       = ["naman.training.app"]
      secret_name = "my-tls-secret-server"
    }
  }
}




