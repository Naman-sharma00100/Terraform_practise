provider "kubernetes" {
    config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_ingress_v1" "my_ingress" {
  metadata {
    name = "my-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    tls {
      secret_name = "my-tls-secret"
       hosts = [ "naman.training.app" ]
    }

    rule {
      host = "naman.training.app"
      http {
        path {
          backend {
            service {
              name = kubernetes_service.my_service.metadata[0].name
              port {
                number = kubernetes_service.my_service.spec[0].port[0].target_port
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "my_service" {
  metadata {
    name = "my-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.my_app.metadata[0].name 
    }

    port {
      protocol = "TCP"
      port = 80
      target_port = 80
    }
  }
}



resource "kubernetes_deployment" "my_app" {
  metadata {
    name = "my-app"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "my-app"
      }
    }

    template {
      metadata {
        labels = {
            app = "my-app"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name = "my-app"
          port {
            container_port = 80
          }
        }
        
      }
    }
  }
}





resource "kubernetes_secret" "my_tls_secret" {
  metadata {
    name = "my-tls-secret"
  }

  data = {
    "tls.crt" =  file("naman.training.app.crt")   
    "tls.key" = file("naman.training.app-key.pem")  

  }
}
