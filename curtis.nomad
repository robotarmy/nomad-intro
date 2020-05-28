job "curtis" {
  region = "global"

  datacenters = ["nomad-intro"]

  # Rolling updates
  update {
    stagger = "10s"
    max_parallel = 1 
  }

  group "cluster" {
    # We want 3  servers initially
    count = 3

    task "yb_master" {
      template {
        data = <<EOH
	   MASTER_JOIN = {{ range $index, $master := service "yb_master.db }}{{ if eq $index 0 }}{{ $master.Address }}:{{ $master.Port }}{{ else}},{{ $master.Address }}:{{ $master.Port }}{{ end }}{{ end }}
        EOH

	destination = "local/tserver.env"
        env         = true
      }
      driver = "docker"
      config {
        image = "yugabytedb/yugabyte"
        port_map {
          yb_master_http = 7000
	  yb_master_rpc = 7100
        }
	args = [
          "--tserver_master_addrs=${MASTER_JOIN}",
          "--replication_factor=3",
          "--fs_data_dirs=/vagrant/_data_1,/vagrant/_data_2"
	 ]
      }
      service {
        name = "db"
        port = "yb_master_http"
        check {
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "2s"
        }
      }
      env {
        DEMO_NAME = "nomad-intro"
      }
      resources {
        cpu = 100
        memory = 32
        network {
          mbits = 100
          port "yb_master_http" {}
          port "yb_master_rpc" {}
        }
      }
    }

    task "yugabyte-tserver" {
      template {
        data = <<EOH
	   MASTER_JOIN = {{ range $index, $master := service "yb_master.db }}{{ if eq $index 0 }}{{ $master.Address }}:{{ $master.Port }}{{ else}},{{ $master.Address }}:{{ $master.Port }}{{ end }}{{ end }}
        EOH

	destination = "local/tserver.env"
        env         = true
      }

      driver = "docker"
      config {
        image = "yugabytedb/yugabyte"
        port_map {
          yb_tserver_http = 9000
          yb_ycql = 9042
          yb_ysql = 5433
          yb_yedis = 6379
        }
	 args = [
           "--tserver_master_addrs=${MASTER_JOIN}",
          "--fs_data_dirs=/vagrant/_data_1,/vagrant/_data_2",
           "--start_pgsql_proxy"
	  ]
      }
      service {
        port = "yb_tserver_http"
        check {
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "2s"
        }
      }
      env {
        DEMO_NAME = "nomad-intro"
      }
      resources {
        cpu = 100
        memory = 32
        network {
          mbits = 100
          port "yb_tserver_http" {}
          port "yb_ycql" {}
          port "yb_ysql" {}
          port "yb_yedis" {}
        }
      }
    }
  }
}
