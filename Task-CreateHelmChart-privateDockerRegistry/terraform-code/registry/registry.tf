provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_secret" "my_tls_secret" {
  metadata {
    name = "my-tls-secret"
  }

  data = {
    "tls.crt" = file("../naman.training.app.crt")
    "tls.key" = file("../naman.training.app-key.pem")

  }
}

resource "kubernetes_secret" "registry_secret" {
  metadata {
    name = "registry-secret"
  }

  data = {
    htpasswd = "dXNlcjE6YWRtaW4="
  }
}

resource "kubernetes_ingress_v1" "registry_ingress" {
  metadata {
    name = "registry-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target"  = "/"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "500m"
    }
  }

  spec {
    rule {
      host = "naman.training.registry"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.registry.metadata[0].name
              port {
                number = kubernetes_service.registry.spec[0].port[0].port
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = ["naman.training.registry"]
      secret_name = "my-tls-secret"
    }
  }
}


resource "kubernetes_service" "registry" {
  metadata {
    name = "registry"
  }

  spec {
    selector = {
      app = "registry"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 5000
    }
  }
}


resource "kubernetes_deployment" "registry" {
  metadata {
    name = "registry"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "registry"
      }
    }

    template {
      metadata {
        labels = {
          app = "registry"
        }
      }

      spec {
        container {
          name  = "registry"
          image = "registry:2"

          port {
            container_port = 5000
          }
        }
      }
    }
  }
}



