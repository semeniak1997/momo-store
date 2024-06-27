
## Network
resource "yandex_vpc_network" "k8s-network" {
  name = "k8s-network"
}

resource "yandex_vpc_subnet" "k8s-subnet" {
  name = "k8s-subnet"
  v4_cidr_blocks = ["10.1.0.0/16"]
  zone           = var.zone
  network_id     = yandex_vpc_network.k8s-network.id
}

## Service account config
resource "yandex_iam_service_account" "sa" {
  name        = "sa"
  description = "K8S service account"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.folder_id
  role = "editor"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  folder_id = var.folder_id
  role = "container-registry.images.puller"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "vpc-publicAdmin" {
  folder_id = var.folder_id
  role = "vpc.publicAdmin"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "certificates-downloader" {
  folder_id = var.folder_id
  role = "certificate-manager.certificates.downloader"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "storage-viewer" {
  folder_id = var.folder_id
  role = "storage.viewer"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "load-balancer.admin" {
  folder_id = var.folder_id
  role = "load-balancer.admin"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "monitoring.editor" {
  folder_id = var.folder_id
  role = "monitoring.editor"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "dns.editor" {
  folder_id = var.folder_id
  role = "dns.editor"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

resource "yandex_resourcemanager_folder_iam_binding" "k8s.clusters.agent" {
  folder_id = var.folder_id
  role = "k8s.clusters.agent"
  members = [ "serviceAccount:${yandex_iam_service_account.sa.id}" ]
}

## k8s Cluster with 2 nodes
resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name = "k8s-cluster" 
  description = "Terraform installed cluser"
  network_id = yandex_vpc_network.k8s-network.id

  service_account_id = yandex_iam_service_account.sa.id
  node_service_account_id = yandex_iam_service_account.sa.id
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.images-puller
  ]

  release_channel = "STABLE"
  
  master {
    zonal {
        zone = yandex_vpc_subnet.k8s-subnet.zone
        subnet_id = yandex_vpc_subnet.k8s-subnet.id
    }
    public_ip = true
  }
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {

    name = "k8s-node-group"
    cluster_id = yandex_kubernetes_cluster.k8s-cluster.id

    instance_template {

      platform_id="standard-v3"

      network_interface {
        nat = true
        subnet_ids = [yandex_vpc_subnet.k8s-subnet.id]
      }

      resources {
        memory = 4
        cores = 2
      }

      boot_disk {
        type = "network-hdd"
        size = 64
      }
    }

    scale_policy {
        auto_scale {
        min     = 1
        max     = 3
        initial = 1
        }
    }

    allocation_policy {
      location {
        zone = var.zone
      }
    }

    maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
    }
 
}

## Security
resource "yandex_vpc_security_group" "k8s-public-services" {
  name = "k8s-public-services"
  network_id = yandex_vpc_network.k8s-network.id
  ingress {
    protocol = "TCP"
    predefined_target = "loadbalancer_healthchecks"
    from_port = 0
    to_port = 65535
  }
  ingress {
    protocol = "ANY"
    predefined_target = "self_security_group"
    from_port = 0
    to_port = 65535
  }
  ingress {
    protocol = "ANY"
    v4_cidr_blocks = concat(yandex_vpc_subnet.k8s-subnet.v4_cidr_blocks)
    from_port = 0
    to_port = 65535
  }
  ingress {
    protocol = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  ingress {
    protocol = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port = 30000
    to_port = 32767
  }
  ingress {
    protocol = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port = 6443
  }
  ingress {
    protocol = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port = 443
  }
  ingress {
    protocol = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port = 80
  }
  egress {
    protocol = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 65535
  }
}

## Public static IP
resource "yandex_vpc_address" "address" {
  name = "static-ip"
  external_ipv4_address {
    zone_id = "ru-central1-d"
  }
}

## DNS zone with records
resource "yandex_dns_zone" "domain" {
  name = replace(var.domain, ".", "-")
  zone = join("", [var.domain, "."])
  public = true
  private_networks = [yandex_vpc_network.k8s-network.id]
}

resource "yandex_dns_recordset" "dns_domain_record" {
  zone_id = yandex_dns_zone.domain.id
  name = join("", [var.domain, "."])
  type = "A"
  ttl = 300
  data = [yandex_vpc_address.address.external_ipv4_address[0].address]
}


## Static key for sa
resource "yandex_iam_service_account_static_access_key" "account-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
}

## New bucket for momo images
resource "yandex_storage_bucket" "ayudaev-images" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = "std-025-02-images"
  acl = "public-read"
}

## Momo images
resource "yandex_storage_object" "momo-img-1" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo1"
  source       = "momo-images/momo1.jpg"
  content_type = "image/jpeg"
}

resource "yandex_storage_object" "momo-img-2" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo2"
  source       = "momo-images/momo2.jpg"
  content_type = "image/jpeg"
}

resource "yandex_storage_object" "momo-img-3" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo3"
  source       = "momo-images/momo3.jpg"
  content_type = "image/jpeg"
}

resource "yandex_storage_object" "momo-img-4" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo4"
  source       = "momo-images/momo4.jpg"
  content_type = "image/jpeg"
}

resource "yandex_storage_object" "momo-img-5" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo5"
  source       = "momo-images/momo5.jpg"
  content_type = "image/jpeg"
}

resource "yandex_storage_object" "momo-img-6" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo6"
  source       = "momo-images/momo6.jpg"
  content_type = "image/jpeg"
}

resource "yandex_storage_object" "momo-img-7" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo7"
  source       = "momo-images/momo7.jpg"
  content_type = "image/jpeg"
}

resource "yandex_storage_object" "momo-img-8" {
  access_key = yandex_iam_service_account_static_access_key.account-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.account-static-key.secret_key
  bucket = yandex_storage_bucket.ayudaev-images.bucket
  acl = "public-read"
  key          = "momo8"
  source       = "momo-images/momo8.jpg"
  content_type = "image/jpeg"
}
