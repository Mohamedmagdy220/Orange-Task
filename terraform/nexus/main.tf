data "kubernetes_namespace" "build" {
  metadata { name = var.namespace }
}

resource "kubernetes_persistent_volume_claim" "nexus_data" {
  metadata {
    name      = "nexus-data"
    namespace = data.kubernetes_namespace.build.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment" "nexus" {
  metadata {
    name      = "nexus"
    namespace = data.kubernetes_namespace.build.metadata[0].name
    labels    = { app = "nexus" }
  }

  spec {
    replicas = 1

    selector { match_labels = { app = "nexus" } }

    template {
      metadata { labels = { app = "nexus" } }

      spec {
        container {
          name  = "nexus"
          image = var.nexus_image

          port { container_port = 8081 } # Nexus UI
          port { container_port = 5000 } # Docker hosted (هنفعّله بعدين)

          resources {
            requests = { cpu = "500m", memory = "1Gi" }
            limits   = { cpu = "1", memory = "2Gi" }
          }

          volume_mount {
            name       = "nexus-data"
            mount_path = "/nexus-data"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 120
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 60
            period_seconds        = 10
          }

        }

        volume {
          name = "nexus-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nexus_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nexus" {
  metadata {
    name      = "nexus"
    namespace = data.kubernetes_namespace.build.metadata[0].name
  }
  spec {
    selector = { app = "nexus" }

    port {
      name        = "http"
      port        = 8081
      target_port = 8081
      node_port   = 30081
    }

    port {
      name        = "docker"
      port        = 5000
      target_port = 5000
      node_port   = 30500
    }

    type = "NodePort"
  }
}
