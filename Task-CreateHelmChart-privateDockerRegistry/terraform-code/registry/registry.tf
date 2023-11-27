provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_secret" "my_tls_secret" {
  metadata {
    name = "my-tls-secret"
  }

  data = {
    "tls.crt" = file("../naman.training.registry.crt")
    "tls.key" = file("../naman.training.registry.key")
  }
}

resource "kubernetes_secret" "registry_secret" {
  metadata {
    name = "registry-secret"
  }

  data = {
    htpasswd = "admin:$2y$05$y67v3WPh/XZPg8aItiYmSesurOCItXLmihm9Du0VUPAT6HMNKP/qK"
  }
}


resource "kubernetes_persistent_volume" "image-registry" {
  metadata {
    name = "image-registry"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name = "standard"
    persistent_volume_source {
      host_path {
        path = "/c/Registry"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "image-registry-claim" {
  metadata {
    name = "image-registry-claim"
  }
  spec {
    access_modes = [ "ReadWriteOnce" ]
    resources {
      requests = {
        storage = "1Gi"
        
      }
    }
    storage_class_name = "standard"
    volume_name = kubernetes_persistent_volume.image-registry.metadata.0.name
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

          env {
            name  = "REGISTRY_AUTH"
            value = "htpasswd"
          }

          env {
            name  = "REGISTRY_AUTH_HTPASSWD_REALM"
            value = "Registry Realm"
          }

          env {
            name  = "REGISTRY_AUTH_HTPASSWD_PATH"
            value = "/var/lib/registry/auth/htpasswd"
          }

          volume_mount {
            name        = "registry-auth"
            mount_path  = "/var/lib/registry/auth"
          }

          volume_mount {
            name        = "registry-data"
            mount_path  = "/var/lib/registry"
          }
        }

        image_pull_secrets {
            name = "registry-auth-secret"
          }

        volume {
          name = "registry-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.image-registry-claim.metadata[0].name
          }
        }

        volume {
          name = "registry-auth"
          secret {
            secret_name = kubernetes_secret.registry_secret.metadata[0].name
          }
        }

      }
    }
  }
}



