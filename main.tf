
data "oci_identity_fault_domains" "fault_domains_per_ad" {
  count               = length(var.ads)
  availability_domain = var.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
}

locals {
  fault_domains_list = [for fd in data.oci_identity_fault_domains.fault_domains_per_ad[0].fault_domains : fd.name]
}

resource "oci_core_instance_configuration" "worker_config" {
  compartment_id = var.compartment_id
  instance_details {
    instance_type = "compute"
    launch_details {
      compartment_id = var.compartment_id
      create_vnic_details {
        assign_public_ip = false
      }
      metadata = {
        ssh_authorized_keys = var.keyfile
        user_data = var.userdata
      }
      shape = var.shape
      shape_config {
        memory_in_gbs = 2
        ocpus = 1
      }
      source_details {
        source_type = "image"
        image_id = var.image_ocid
      }
    }
  }
  display_name = "worker-instance-config"
}
resource "oci_core_instance_pool" "worker_pool" {
  compartment_id = var.compartment_id
  instance_configuration_id = oci_core_instance_configuration.worker_config.id
  placement_configurations {
    availability_domain = lookup(var.ads.availability_domains[0], "name")
    primary_subnet_id = var.workers_net.id
    fault_domains       = local.fault_domains_list[0]
  }
  lifecycle {
    create_before_destroy = true
  }
  size = 2
  state = "RUNNING"
  display_name = "workers-pool"
  instance_display_name_formatter = "host-$${launchCount}"
  instance_hostname_formatter = "host-$${launchCount}"
}

resource "oci_autoscaling_auto_scaling_configuration" "workers_pool_autoscale" {
  compartment_id = var.compartment_id
  auto_scaling_resources {
    id = oci_core_instance_pool.worker_pool.id
    type = "instancePool"
  }
  cool_down_in_seconds = 300
  policies {
    capacity {
      initial = 1
      max = 3
      min = 1
    }
    policy_type = "threshold"
    rules {
      action {
        type = "CHANGE_COUNT_BY"
        value = 1
      }
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "GT"
          value = "70"
        }
      }
      display_name = "scale-out"
    }
    rules {
      action {
        type = "CHANGE_COUNT_BY"
        value = -1
      }
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "LT"
          value = "30"
        }
      }
      display_name = "scale-in"
    }
    display_name = "workers-pool-autoscale-policy"
  }
  display_name = "workers-pool-autoscale"
}
/*
resource "oci_core_instance" "worker_pool_instance" {
  count = length(var.ads)
  availability_domain = lookup(var.ads.availability_domains[count.index], "name")
  compartment_id      = var.compartment_id
  display_name        = "TestInstanceForInstancePool${count.index}"
  instance_configuration_id = oci_core_instance_configuration.worker_config.id
  shape = var.shape
}

resource "oci_core_instance_pool_instance" "test_instance_pool_instance" {

  instance_pool_id = oci_core_instance_pool.worker_pool.id
    instance_id = oci_core_instance.test_instance.id
    decrement_size_on_delete = true
    auto_terminate_instance_on_delete = false
  }
  }
*/

