provider "kubernetes" {
    config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_service_v1" "nginx_service" {
  metadata {
    name = "nginx-service"
  }

  spec {
    selector = {
      app = "mypod"
    }

    port {
      protocol   = "TCP"
      port       = 80
    }
  }
}

resource "kubernetes_service" "my-backend-api" {
  metadata {
    name = "my-backend-api"
    labels = {
      app = "my-backend-api"
    }
  }

  spec {
    type = "ClusterIP"  

    port {
      port        = 80
      protocol    = "TCP"
      target_port = 80
    }

    selector = {
      app = "my-backend-api"
    }
  }
}

resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name = "nginx-config"
  }

  data = {
    "default.conf" = <<-EOT
      server {
        listen 80;
        autoindex on;

        location / {
          root /usr/share/nginx/html;
          index index.html;
        }
        location /secure {
          alias /usr/share/nginx/html/secure;
          index index.html;
          try_files $uri $uri/ =404;
        }
        location /insecure {
          alias /usr/share/nginx/html/insecure;
          index index.html;
        }
      }
    EOT
  }
}





resource "kubernetes_ingress_v1" "secure_ingress" {
  metadata {
    name = "secure-ingress"
    annotations = {
      "kubernetes.io/ingress.class"            = "nginx"
      "nginx.ingress.kubernetes.io/auth-type" = "basic"
      "nginx.ingress.kubernetes.io/auth-secret" = "basic-auth"
      "nginx.ingress.kubernetes.io/auth-realm" = "Authentication required"
    }
  }

  spec {
    rule {
      host = "naman.training.app"

      http {
        path {
          path     = "/secure/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.nginx_service.metadata[0].name
              port {
                number = kubernetes_service_v1.nginx_service.spec[0].port[0].port
              }
            }
          }
        }
      }
    }

    tls {
      hosts = ["naman.training.app"]
      secret_name = "my-tls-secret"
    }
  }
}

resource "kubernetes_ingress_v1" "insecure_ingress" {
  metadata {
    name = "insecure-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      host = "naman.training.app"
      http {
        path {
          path     = "/insecure"
          backend {
            service {
              name = kubernetes_service_v1.nginx_service.metadata[0].name
              port {
                number = kubernetes_service_v1.nginx_service.spec[0].port[0].port
              }
            }
          }
        }
      }
    }

    tls {
      hosts = ["naman.training.app"]
      secret_name = "my-tls-secret"
    }
  }
}

resource "kubernetes_ingress_v1" "api_ingress" {
  metadata {
    name = "api-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target": "/$2"
    }
  }
  spec {
    rule {
      host = "naman.training.app"
      http {
        path {
          path     = "/job(/|$)(.*)"
          path_type = "Prefix"
          backend {
            service {
              name = "my-backend-api"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    tls {
      hosts = ["naman.training.app"]
      secret_name = "my-tls-secret"
    }
  }
}

resource "kubernetes_deployment" "my-backend-api" {
  metadata {
    name = "my-backend-api"
    labels = {
      app = "my-backend-api"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "my-backend-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "my-backend-api"
        }
      }

      spec {
        container {
          name  = "my-backend-api"
          image = "numcys/my-backend-api"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "mypod" {
  metadata {
    name = "mypod"
    labels = {
      app = "mypod"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "mypod"
      }
    }

    template {
      metadata {
        labels = {
          app = "mypod"
        }
      }

      spec {
        volume {
          name = "html-files"

          empty_dir {}
        }

        volume {
          name = "nginx-config"

          config_map {
            name = "nginx-config"
          }
        }

        container {
          name  = "nginx-container"
          image = "nginx"

          volume_mount {
            name       = "html-files"
            mount_path = "/usr/share/nginx/html"
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
          }

          command = ["/bin/sh", "-c"]

          args = [ 
            "mkdir -p /usr/share/nginx/html/insecure /usr/share/nginx/html/secure && echo '<html><body><h1>This is the HOME page</h1></body></html>' > /usr/share/nginx/html/index.html && echo '<html><body><h1>This is an insecure page</h1></body></html>' > /usr/share/nginx/html/insecure/index.html && echo '<html><body><h1>This is a secure page</h1></body></html>' > /usr/share/nginx/html/secure/index.html && exec nginx -g 'daemon off;'",
          ]
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

resource "kubernetes_secret" "basic_auth" {
  metadata {
    name = "basic-auth"
  }

  data = {
    auth = file("./auth")
  }
}