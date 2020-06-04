job "hive-database" {
  type        = "service"
  datacenters = ["dc1"]
  group "database" {
    count = 1

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
      canary            = 1
      stagger           = "30s"
    }

    service {
      name = "hive-database"
      port = 5432

      check {
        type     = "script"
        task     = "postgresql"
        command  = "/usr/local/bin/pg_isready"
        args     = ["-U", "hive"]
        interval = "30s"
        timeout  = "2s"
      }

      connect {
        sidecar_service {}
      }
    }

    network {
      mode = "bridge"
    }

    //    ephemeral_disk {
    //      migrate = true
    //      size    = 100
    //      sticky  = true
    //    }

    task "postgresql" {
      driver = "docker"

      env {
        POSTGRES_DB       = "metastore"
        POSTGRES_USER     = "hive"
        POSTGRES_PASSWORD = "hive"
        PGDATA            = "/var/lib/postgresql/data"
      }

      config {
        image = "postgres:12-alpine"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      logs {
        max_files     = 10
        max_file_size = 2
      }
    }
  }
}
