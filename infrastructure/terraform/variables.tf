variable "cloud_id" {
  type    = string
  default = ""
}

variable "folder_id" {
  type    = string
  default = ""
}

variable "token" {
  type    = string
  default = ""
}
variable "zone" {
  type    = string
  default = "ru-central1-d"
}
variable "domain" {
  type    = string
  default = "std-025-02-momo-store.ru"
  description = "DNS domain"
  sensitive = true
}

