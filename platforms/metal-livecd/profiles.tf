// CoreOS Install Profile
resource "matchbox_profile" "coreos_livecd_controller" {
  name   = "coreos-livecd-controller"
  kernel = "/assets/coreos/${var.tectonic_metal_cl_version}/coreos_production_pxe.vmlinuz"

  initrd = [
    "/assets/coreos/${var.tectonic_metal_cl_version}/coreos_production_pxe_image.cpio.gz",
  ]

  args = [
    "coreos.config.url=${var.tectonic_metal_matchbox_http_url}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "coreos.autologin",
    "console=tty0",
    "console=ttyS1,115200",
    "rootflag=loop",
    "rootfstype=tmpfs",
    "root=/assets/coreos/${var.tectonic_metal_cl_version}/coreos_production_iso_image.iso",
    "initrd=coreos_production_pxe_image.cpio.gz"
  ]

  container_linux_config = "${file("${path.module}/cl/bootkube-controller.yaml.tmpl")}"
}

resource "matchbox_profile" "coreos_livecd_worker" {
  name   = "coreos-livecd-worker"
  kernel = "/assets/coreos/${var.tectonic_metal_cl_version}/coreos_production_pxe.vmlinuz"

  initrd = [
    "/assets/coreos/${var.tectonic_metal_cl_version}/coreos_production_pxe_image.cpio.gz",
  ]

  args = [
    "coreos.config.url=${var.tectonic_metal_matchbox_http_url}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "coreos.autologin",
    "console=tty0",
    "console=ttyS1,115200",
    "rootflag=loop",
    "rootfstype=tmpfs",
    "root=/assets/coreos/${var.tectonic_metal_cl_version}/coreos_production_iso_image.iso",
    "initrd=coreos_production_pxe_image.cpio.gz"
  ]

  container_linux_config = "${file("${path.module}/cl/bootkube-worker.yaml.tmpl")}"
}

// Self-hosted Kubernetes Controller profile
resource "matchbox_profile" "tectonic_controller" {
  name                   = "tectonic-controller"
  container_linux_config = "${file("${path.module}/cl/bootkube-controller.yaml.tmpl")}"
}

// Self-hosted Kubernetes Worker profile
resource "matchbox_profile" "tectonic_worker" {
  name                   = "tectonic-worker"
  container_linux_config = "${file("${path.module}/cl/bootkube-worker.yaml.tmpl")}"
}
