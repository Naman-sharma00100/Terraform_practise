provider "kubernetes" {
    config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "example-depl"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "example"
      }
    }

    template {
      metadata {
        labels = {
          app = "example"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
