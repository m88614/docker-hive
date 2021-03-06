job "hive" {
  type = "service"
  datacenters = ["dc1"]

  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "10m"
    progress_deadline = "12m"
    auto_revert = true
    auto_promote = true
    canary = 1
    stagger = "30s"
  }

  group "server" {
    count = 1

    network {
      mode = "bridge"
      port "healthcheck" {
        to = -1
      }
    }

    task "waitfor-hive-metastore" {
        restart {
            attempts = 10
            delay    = "15s"
        }
      lifecycle {
        hook = "prestart"
      }
      driver = "docker"
      resources {
        memory = 32
      }
      config {
        image = "consul:latest"
        entrypoint = ["/bin/sh"]
        args = ["-c", "jq </local/service.json -e '.[].Status|select(. == \"passing\")'"]
        volumes = ["tmp/service.json:/local/service.json" ]
      }
      template {
        destination = "tmp/service.json"
        data = <<EOH
          {{- service "hive-metastore" | toJSON -}}
        EOH
      }
    }

    service {
      name = "hive-server"
      port = 10000

      check {
        name = "jmx"
        type = "http"
        port = "healthcheck"
        path = "/jmx"
        interval = "30s"
        timeout = "2s"
      }

      check {
        name = "beeline"
        type = "script"
        task = "hiveserver"
        command = "/bin/bash"
        args = [
          "-c",
          "beeline -u jdbc:hive2:// -e \"SHOW DATABASES;\" &> /tmp/script_connect_beeline_hive-server.txt &&  echo \"return code $?\""]
        interval = "30s"
        timeout = "120s"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "hive-metastore"
              local_bind_port = 9083
            }
            upstreams {
              destination_name = "minio"
              local_bind_port = 9000
            }
            //Inspiration: https://github.com/hashicorp/nomad/issues/7709
            expose {
              path {
                path = "/jmx"
                protocol = "http"
                local_path_port = 10002
                listener_port = "healthcheck"
              }
            }
          }
        }
      }
    }

    task "hiveserver" {
      driver = "docker"

      config {
        image = "fredrikhgrelland/hive:3.1.0"
        command = "hiveserver"
      }

      resources {
        cpu = 500
        memory = 1024
      }

      logs {
        max_files = 10
        max_file_size = 2
      }

      template {
        destination = "local/config.env"
        env = true
        data = <<EOH
HIVE_SITE_CONF_hive_metastore_uris="thrift://{{ env "NOMAD_UPSTREAM_ADDR_hive-metastore" }}"
HIVE_SITE_CONF_hive_execution_engine="mr"
HIVE_SITE_CONF_hive_support_concurrency=false
HIVE_SITE_CONF_hive_driver_parallel_compilation=true
HIVE_SITE_CONF_hive_metastore_warehouse_dir="s3a://hive/warehouse"
HIVE_SITE_CONF_hive_metastore_event_db_notification_api_auth=false
HIVE_SITE_CONF_hive_server2_active_passive_ha_enable=true
HIVE_SITE_CONF_hive_server2_enable_doAs=false
HIVE_SITE_CONF_hive_server2_thrift_port=10000
HIVE_SITE_CONF_hive_server2_thrift_bind_host="127.0.0.1"
HIVE_SITE_CONF_hive_server2_authentication="NOSASL"
CORE_CONF_fs_defaultFS = "s3a://default"
CORE_CONF_fs_s3a_connection_ssl_enabled = false
CORE_CONF_fs_s3a_endpoint = "http://{{ env "NOMAD_UPSTREAM_ADDR_minio" }}"
CORE_CONF_fs_s3a_path_style_access = true
EOH
      }

      template {
        destination = "secrets/.env"
        env = true
        data = <<EOH
CORE_CONF_fs_s3a_access_key = "minioadmin"
CORE_CONF_fs_s3a_secret_key = "minioadmin"
EOH
      }
    }
  }

  group "metastore" {
    count = 1

    service {
      name = "hive-metastore"
      port = 9083

      check {
        name = "beeline"
        type = "script"
        task = "metastoreserver"
        command = "/bin/bash"
        args = [
          "-c",
          "beeline -u jdbc:hive2:// -e \"SHOW DATABASES;\" &> /tmp/check_script_beeline_metastoreserver && echo \"return code $?\""]
        interval = "30s"
        timeout = "120s"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "hive-database"
              local_bind_port = 5432
            }
            upstreams {
              destination_name = "minio"
              local_bind_port = 9000
            }
          }
        }
      }
    }

    network {
      mode = "bridge"
    }

    task "waitfor-hive-database" {
        restart {
            attempts = 5
            delay    = "15s"
        }    
      lifecycle {
        hook = "prestart"
      }
      driver = "docker"
      resources {
        memory = 32
      }
      config {
        image = "consul:latest"
        entrypoint = ["/bin/sh"]
        args = ["-c", "jq </local/service.json -e '.[].Status|select(. == \"passing\")'"]
        volumes = ["tmp/service.json:/local/service.json" ]
      }
      template {
        destination = "tmp/service.json"
        data = <<EOH
          {{- service "hive-database" | toJSON -}}
        EOH
      }
    }

    task "waitfor-minio-has-required-buckets" {
      # `default` & `hive` buckets
      lifecycle {
        hook = "prestart"
      }
      driver = "docker"
      config {
        image = "minio/mc:latest"
        entrypoint = [
          "/bin/sh",
          "-c",
          # adding config command could fail, if minio not available or bad credentials
          # if buckets already exists => exit 0
          "mc config host add myminio http://${NOMAD_UPSTREAM_ADDR_minio} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} || exit 2 && mc mb myminio/hive || true && mc mb myminio/default || true"
        ]
      }
      template {
        destination = "secrets/.env"
        env = true
        data = <<EOH
MINIO_ACCESS_KEY = "minioadmin"
MINIO_SECRET_KEY = "minioadmin"
EOH
      }
    }

    task "metastoreserver" {
      driver = "docker"

      config {
        image = "fredrikhgrelland/hive:3.1.0"
        command = "hivemetastore"
      }

      resources {
        cpu = 500
        memory = 1024
      }

      logs {
        max_files = 10
        max_file_size = 2
      }

      template {
        destination = "local/config.env"
        env = true
        data = <<EOH
HIVE_SITE_CONF_javax_jdo_option_ConnectionURL="jdbc:postgresql://{{ env "NOMAD_UPSTREAM_ADDR_hive-database" }}/metastore"
HIVE_SITE_CONF_javax_jdo_option_ConnectionDriverName="org.postgresql.Driver"
HIVE_SITE_CONF_datanucleus_autoCreateSchema=false
HIVE_SITE_CONF_hive_metastore_uris="thrift://127.0.0.1:9083"
HIVE_SITE_CONF_hive_metastore_schema_verification=true
HIVE_SITE_CONF_hive_execution_engine="mr"
HIVE_SITE_CONF_hive_support_concurrency=false
HIVE_SITE_CONF_hive_driver_parallel_compilation=true
HIVE_SITE_CONF_hive_metastore_warehouse_dir="s3a://hive/warehouse"
HIVE_SITE_CONF_hive_metastore_event_db_notification_api_auth=false
CORE_CONF_fs_defaultFS = "s3a://default"
CORE_CONF_fs_s3a_connection_ssl_enabled = false
CORE_CONF_fs_s3a_endpoint = "http://{{ env "NOMAD_UPSTREAM_ADDR_minio" }}"
CORE_CONF_fs_s3a_path_style_access = true
EOH
      }

      template {
        destination = "secrets/.env"
        env = true
        data = <<EOH
CORE_CONF_fs_s3a_access_key = "minioadmin"
CORE_CONF_fs_s3a_secret_key = "minioadmin"
HIVE_SITE_CONF_javax_jdo_option_ConnectionUserName="hive"
HIVE_SITE_CONF_javax_jdo_option_ConnectionPassword="hive"
EOH
      }
    }
  }

  group "database" {
    count = 1

    service {
      name = "hive-database"
      port = 5432

      check {
        type = "script"
        task = "postgresql"
        command = "/usr/local/bin/pg_isready"
        args = [
          "-U",
          "hive"]
        interval = "30s"
        timeout = "2s"
      }

      connect {
        sidecar_service {}
      }
    }

    network {
      mode = "bridge"
    }

    task "postgresql" {
      driver = "docker"

      env {
        POSTGRES_DB = "metastore"
        POSTGRES_USER = "hive"
        POSTGRES_PASSWORD = "hive"
        PGDATA = "/var/lib/postgresql/data"
      }

      config {
        image = "postgres:12-alpine"
      }

      resources {
        cpu = 200
        memory = 256
      }

      logs {
        max_files = 10
        max_file_size = 2
      }
    }
  }
}
