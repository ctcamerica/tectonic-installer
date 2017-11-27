# Assumption
  1. Tested with tectonic-installer (1.7.5-tectonic.1).
  2. matchbox is expected run as container.
  3. dnsmasq is expected run as container.
  4. matchbox and dnsmasq is expected to run on the same container host.
  5. Network address for PXE network is 10.10.10.0/24.
  6. Container hosts on which matchbox and dnsmasq will run has an address 10.10.10.120.
  7. Target nodes is expected boot in UEFI mode.
  8. Network boot with ipv6 is expected to be disabled.
  9. tectonic license is expected to be downloaded from "https://account.coreos.com/" and saved as  /home/core/tectonic_license.txt on container host.
  10. tectonic pull secret is expected to be downloaded from "https://account.coreos.com/" and saved as "/home/core/tectonic_pull_secret.json" on container host.

# Setup dnsmasq[@CoreOS Livecd]
  - Run the following command on container host.

```
wget http://boot.ipxe.org/ipxe.efi
sudo docker run --rm --cap-add=NET_ADMIN --net=host -v `pwd`/ipxe.efi:/var/lib/tftpboot/ipxe.efi -v `pwd`/coreos:/var/lib/tftpboot/coreos quay.io/coreos/dnsmasq \
-d -q \
--dhcp-range=10.10.10.198,10.10.10.199 \
--enable-tftp --tftp-root=/var/lib/tftpboot \
--dhcp-userclass=set:ipxe,iPXE \
--dhcp-boot=tag:#ipxe,ipxe.efi \
--dhcp-boot=tag:ipxe,http://matchbox.example.com:8080/boot.ipxe \
--dhcp-host=c4:54:44:d3:86:9a,10.10.10.197 \
--dhcp-host=c4:54:44:d3:86:06,10.10.10.198 \
--dhcp-host=c4:54:44:d3:85:78,10.10.10.199 \
--address=/matchbox.example.com/10.10.10.120 --log-queries --log-dhcp
```

*In this document, As the target node is expected to boot from PXE in UEFI mode, ipxe.efi should be provided instead of undionly.kpxe. ipxe.efi is downloaded from http://boot.ipxe.org and mounted by dnsmasq container to be located in tftp root directory on launching. This is because quay.io/coreos/dnsmasq:0.4.1 does not have ipxe.efi as default.
*If the target node boots from PXE in Legacy BIOS mode, chaining file for ipxe should be specified by "--dhcp-boot=tag:#ipxe,undionly.kpxe" to use undionly.kpxe.

# Setup Matchbox[@CoreOS Livecd]
  - Run the following command on container host.

```
wget https://github.com/coreos/matchbox/releases/download/v0.6.1/matchbox-v0.6.1-linux-amd64.tar.gz
wget https://github.com/coreos/matchbox/releases/download/v0.6.1/matchbox-v0.6.1-linux-amd64.tar.gz.asc
tar xzvf matchbox-v0.6.1-linux-amd64.tar.gz
cd matchbox-v0.6.1-linux-amd64
sudo mkdir -p /var/lib/matchbox/assets
./scripts/get-coreos stable 1520.8.0 .
sudo cp -r coreos /var/lib/matchbox/assets
sudo wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_iso_image.iso
sudo cp coreos_production_iso_image.iso /var/lib/matchbox/assets
cd scripts/tls/
export SAN=DNS.1:matchbox.example.com,IP.1:10.10.10.120
./cert-gen
sudo mkdir -p /etc/matchbox
sudo cp ca.crt server.crt server.key /etc/matchbox/
sudo docker run --net=host --rm -v /var/lib/matchbox:/var/lib/matchbox:Z -v /etc/matchbox:/etc/matchbox:Z,ro quay.io/coreos/matchbox:latest -address=0.0.0.0:8080 -rpc-address=0.0.0.0:8081 -log-level=debug
```

# Download and setup Tectonic installer
  - Run the following command on container host.

```
curl -O https://releases.tectonic.com/releases/tectonic_1.7.5-tectonic.1.tar.gz
tar xzvf tectonic_1.7.5-tectonic.1.tar.gz
cd tectonic
export INSTALLER_PATH=$(pwd)/tectonic-installer/linux/installer
export PATH=$PATH:$(pwd)/tectonic-installer/linux
terraform init ./platforms/metal
export CLUSTER=my-cluster
mkdir -p build/${CLUSTER}
cp examples/terraform.tfvars.metal build/${CLUSTER}/terraform.tfvars
cat << EOF > terraform.tfvars.metal-livecd
tectonic_admin_email = ""
tectonic_admin_password_hash = ""
tectonic_base_domain = ""
tectonic_calico_network_policy = false
tectonic_cl_channel = "stable"
tectonic_cluster_cidr = "10.2.0.0/16"
tectonic_cluster_name = "ocp-tectonic"
tectonic_etcd_count = "0"
tectonic_experimental = true
tectonic_license_path = "/home/core/tectonic_license.txt"
tectonic_master_count = "1"
tectonic_metal_cl_version = "1520.8.0"
tectonic_metal_controller_domain = "node1.example.com"
tectonic_metal_controller_domains = ["node1.example.com"]
tectonic_metal_controller_macs = ["c4:54:44:d3:86:9a"]
tectonic_metal_controller_names = ["node1"]
tectonic_metal_ingress_domain = "tectonic.exmaple.com"
tectonic_metal_matchbox_ca = <<EOD
-----BEGIN CERTIFICATE-----
MIIFDTCCAvWgAwIBAgIJAPgM6y0IdR8zMA0GCSqGSIb3DQEBCwUAMBIxEDAOBgNV
BAMMB2Zha2UtY2EwHhcNMTcxMTA4MjM0ODU5WhcNMjcxMTA2MjM0ODU5WjASMRAw
DgYDVQQDDAdmYWtlLWNhMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
yoyWjO6Jop9KxOmxq0P0JVA+AIuLVpUPu2wzTTvYmGea+5tffPpA/VUBFGiNY9hv
Lg9ZlhvVJKSEbW6VAjXFkHUHz6x0MBUCCIZMEGJuibReQ8hJtBqMrITd6nKVx1eG
+RdZr0SCL5TKxFOmK0lRikq8+dY4cMXAeRHv7BNafXcfj0MGUcDjM+GlpkjlArua
0Gk74C8uWQp5Elb8yjWwCmzyuCZNidmsst/PvRJFYSeMhaVVy6lohrHwk/apo36E
T5/c5UtZ728KDCCcxX8Ep967Ztfg/kK/WNTeaqD+kV5VnIx1DmY45rPrWQw7DpgO
5hoGa92TTsSrUwrgqpJYxrG3/HA1ehR+DPek6AtyL/YBzjP10UJON0zMRhp8e/Lz
nrSBZXRnBono30RRblto/UiX4quetsukHviwfjU31GA9GkV/ONxdYRdKZqbkC+IQ
Ex9ATZXdxPLdRsA3J1PYgwA6m3MzPvyBQQVQMpqQjFp3jGoylcRJCCpbq9sBfZFk
ajrrasl/RJxLThNJ7CIx3Ok88uDMbcOgs+f4KZHHMmIdGO4KoxolH9AY6L2MymXH
VtXOSx6lzN0Q3maexXT94GaakHE4gRflS7sk8WZ9u51E+C8aNonsLxjcWPlfbCrQ
tfOmLj6n9qYnQjhqRrRM/KDiGxGr5M6cu1mnbtJ43AMCAwEAAaNmMGQwHQYDVR0O
BBYEFMur2ykYK/MN3AROh9s6Kl5SiAh6MB8GA1UdIwQYMBaAFMur2ykYK/MN3ARO
h9s6Kl5SiAh6MBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMA0G
CSqGSIb3DQEBCwUAA4ICAQAmIuvBPu/Sga86lWswgMDpqOgAzeNcF9HCDhE77nQ+
c+2bK8niPzPTYwLs4sa94924nejeyMCPq/30Dfjol+FZMW245HOCQ+5CEX/Dlf2J
cHbRk6aX3spOMlU3F99MyeMQstYfjPfwiQiEtmBpDhmuEe8c4J/AGaC463VAWQ6u
7xphj2X3GNLR3cZtUqg7swaeVmLROZ1FNsHOUfRWLRX9lgPOkGJuNmNZ8olJ69LK
awC3kzBUAdnNs+SJ1eNsm1rLGyskNIhURB593lmD/BCkFRMCJ45WAQYwX7F82qz+
HGcveZqe4/VJa2eE+++jUPfFPnkH/Jy5G4R5rJP85J13Aj+ZCgB/WvO7IxUaAyCX
sekyNVwPp55edpJevxs8W7az9cyQMQihHVlnVaqFO9tBlH8xz4qHhR68S6psvPvo
mLOkMppCCsBQ2d8DLiBJTLffTSITSWLR+VljZZJsSKeIEUEma+PrOfswcu4Wj97D
bxpEoida7TcKW0pMvhPTno4Yoap4BpKA/YsHPLr/C9mDIMXhkCy5KVXMrSJpWr1w
RE7jd/ToHQhw0uifn0LoYTRNQITcjfPPFykGhnfsJcrTSptqSyoU+EI9kAB5hpkz
E88hBQxLCeZfjs3q8ScIt/PqRePEfFmuE/+o4AlCTJZ+LDVFnb2ejrkVIP+ojDrB
vA==
-----END CERTIFICATE-----
EOD
tectonic_metal_matchbox_client_cert = <<EOD
-----BEGIN CERTIFICATE-----
MIIEYDCCAkigAwIBAgICEAEwDQYJKoZIhvcNAQELBQAwEjEQMA4GA1UEAwwHZmFr
ZS1jYTAeFw0xNzExMDgyMzQ4NTlaFw0xODExMDgyMzQ4NTlaMBYxFDASBgNVBAMM
C2Zha2UtY2xpZW50MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5p5Y
e1YpCtOvzaeHXkPK3z9RKKbT8mnWjK0efOxaA+JOdYzj7Bgl+/osWpdv+UOUmxrv
QB+buDn5ZZbTyBmfYZQujyybUbihdbUZQ4UrCKLjG5aRs46yGnQEPq/tqzKbtoi8
vgV/YXrH2xyWjArYtFw1sSiWHYmA9L+zMTQI1sEh9fcwxuaBY3zX0jYCAHA8My8S
S6QKVbWZtoOP6iEmjQzRkZb0gJMw6aq5CyQ+M5yV+FVL4LCHcdasmswKgwCy9D/2
vNP6qnHMzOmJtV+kSUP1mqx2Wctc77OEjm07UNTpWwSr484iJdIHocsTe7FMbyU8
HSUWSznutMN/t9sI7QIDAQABo4G7MIG4MAkGA1UdEwQCMAAwEQYJYIZIAYb4QgEB
BAQDAgeAMDMGCWCGSAGG+EIBDQQmFiRPcGVuU1NMIEdlbmVyYXRlZCBDbGllbnQg
Q2VydGlmaWNhdGUwHQYDVR0OBBYEFCJL1qDx9R5IXP78yFscDdVVzJc3MB8GA1Ud
IwQYMBaAFMur2ykYK/MN3AROh9s6Kl5SiAh6MA4GA1UdDwEB/wQEAwIF4DATBgNV
HSUEDDAKBggrBgEFBQcDAjANBgkqhkiG9w0BAQsFAAOCAgEAnn1tOwgBn78+SAYm
Oo0/gmE90eaMzx+o8LTzCuCULQnfA1vVhpblpTNdJZY4FFP/w2WS2MLrK18zbbcO
/AhzSHQ16v0TPYpvjQ1Rs1PSonUjKTgg5MYW27Bhx7cssU9aKqSDdiST+yBMiAJf
utVSHSeFYF6G3qksJgro3s0URTYzKHM0DOmNL1mymJ60qLGGi+YCaF79VCU++v1K
QbdVWy4OwHahAfswgz2+jMSkmGpzfpJjupAd5EsFom/5dL2p1MFsry60WVB1tiMu
gUsVZjsg65iRQq04wiutBbVSRVW+tM0AJPaB2SIPpIWHS718aZmx/ih8g5snNg+T
jLrmZ6IdDkP7HtWonU5rGkhuyIBh7n/BR6iDSPqjV2uRZ1LVj3Wpun/59hys6kfW
yGLfy/3NrqQEffOvmtn6/dncOAThjRsr5bW639Cab7eS0KXb5GqYJhnhmsSRnaZI
P+huzDu/4is8f0YhyxS229GrMSDEkC605LvJLFOWV5VojGQqUXamDMHX6jF8O9pa
T4EEPzn9++VZrE1+nmR/b/eiS92FGd4Jvq2jXp/5E0X+MAe0nqZ7FaRS8JN3yfHe
4pHcFLHVfH66pUN4tTb5RkKzRasN//aOtTJJrjXmDQ5oAQPwbpz/hnlyKgbIGJNG
bQfb3ssDDtVcv0/Sntezb6rO17M=
-----END CERTIFICATE-----
EOD
tectonic_metal_matchbox_client_key = <<EOD
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA5p5Ye1YpCtOvzaeHXkPK3z9RKKbT8mnWjK0efOxaA+JOdYzj
7Bgl+/osWpdv+UOUmxrvQB+buDn5ZZbTyBmfYZQujyybUbihdbUZQ4UrCKLjG5aR
s46yGnQEPq/tqzKbtoi8vgV/YXrH2xyWjArYtFw1sSiWHYmA9L+zMTQI1sEh9fcw
xuaBY3zX0jYCAHA8My8SS6QKVbWZtoOP6iEmjQzRkZb0gJMw6aq5CyQ+M5yV+FVL
4LCHcdasmswKgwCy9D/2vNP6qnHMzOmJtV+kSUP1mqx2Wctc77OEjm07UNTpWwSr
484iJdIHocsTe7FMbyU8HSUWSznutMN/t9sI7QIDAQABAoIBAEI0ZvZRT8r55lhF
pcjb8VuRk7z115aZ56vO7xexyk2fJCL+5VebvxvNP/ppyw1l5z13yANCj7OdgQk2
+WlSYbzji1Iy3gvh0wg1iyElE6uRB12eJgnEB0Es2SMd4j7pcmY+buCmN2FGnCU8
2cMuQfPVHNzU5/NmzAx3E/wmEfuEPrVaBSuS1RuiZFaTwmratbGlfW+WLX4+Fq+a
8hApc6U6Qr+aj1UQ4RWronWt+DS/zywjVVkOoEZJehtZl9jYjdjAJBLIoIsGp/sN
Zuy2N70a7UPeA7egBOTKEILsutSjVLseJd46L01POkG5RCGjc2cgb4NH3nK9s3dn
3816y4kCgYEA9bysAqntlITkcZB5kqSXN1BOVcW010CLrYMyIPZHxBuAZY/GJAXo
gNPBah/Nw1McsDyaTNX/W3WiqAXNSUNGuC5wnblQL/UCwnKBVMY4zrXc4+Ef+DNF
aPis5KduwRvMzu1SBvz4Eyi1h0SyOi6z0rDL0Q8zJWBbRzdWSe17lJsCgYEA8EAI
Y/KSwWcbPmAa9k21XJBuZYiGYnTFfb5wn/oIhXxTkpkbQi70hEqIc+KKu2Qa73MJ
G1a6TCqpFhG4TzClA/r8YBOknu0tr7w4xgJgVLNXsDv3jrOMczSf9OCi6AX6Ecuu
qFNWNvIHMu1yB8UCMlOlcdydazU3O3ah0zsjfRcCgYA2sBNz0E9wQxb38xgrO3fv
tm6IhiRV1yZ+qfjo/wY/rYMolxOYhrwUl4uuy38mXgO/cO1B9koLF6XoUMo76L3/
VU54u3oOAi/oCEWiES8pSa3sBPjxaq+iydzoUh7C2SX+UzBzH68xzFiBzxb+/c/F
LtVdJE3UnpoRwk3wy+o5ywKBgCoIae9inz5rFZ8iHVV+Xv6k3kuxSSGsoGjRis7S
Ze9EwzJgyx4XLPyANcNgnTkP2I6QJ8W6tLlitVaBHyfrsNMzdDgy95g+ksGuQpiS
DdyDzBGvTC6RRz9Ys6uaKaZCdW/rnNEiU3ElgxDr7glh9HJtpAJ5wKjjFJi4trNI
I3tdAoGBALhn7I0dC9AFWx7ygGw3p/VvN5O/cyr2q9a6YecybDGk06lJUM6pLJy5
BS9JN5uhn6EwJC15JVXDubo4JrbirGSQ2sH8QvOdqlI8LFbcsHyb1nCZ9NOZPJBL
ga5Vt68CqPU8FpGMNzTkGB7sORr5k7MDh50gfEKe7ipERhm1UBhf
-----END RSA PRIVATE KEY-----
EOD
tectonic_metal_matchbox_http_url = "http://matchbox.example.com:8080"
tectonic_metal_matchbox_rpc_endpoint = "matchbox.example.com:8081"
tectonic_metal_worker_domains = ["node2.example.com", "node3.example.com"]
tectonic_metal_worker_macs = ["c4:54:44:d3:86:06", "c4:54:44:d3:85:78"]
tectonic_metal_worker_names = ["node2", "node3"]
tectonic_pull_secret_path = "/home/core/tectonic_pull_secret.json"
tectonic_service_cidr = "10.3.0.0/16"
tectonic_ssh_authorized_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCT0UlLHG5FcTYIibDp1y2ksKuxYNEdpL+B7EOTWVDCwe7WSvlsWTr/PN6beyVU/BfzGUxH6pIWp4r3bwv5cIBA/kwn3A/qUb8/SjLl+67p0DgXkstFjwWQNSdnc/UY3ttHBX2UN3rJyeOlrNU4BV7D7548mIx1pEWS6e5rfgwJk2kwZ2eY0nFKHVrh/YTcAUKtHMzbirOcIwTZKlGQfhPnOG8jemAYNV1DcfoLiFKu/TNkh9Yk5reMIOlxJeNzKGwNkhYFJXoTnuRhPkd6jdRZRh5FyHp54QnJYqHqE83KuA01jE7B//NIk8T8kzPIrRBH7zwXzaL16yME1Cao3JSr core@localhost"
tectonic_stats_url = "https://stats-collector.tectonic.com"
tectonic_vanilla_k8s = false
tectonic_worker_count = "3"
EOF
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa
terraform plan -var-file=./build/my-cluster/terraform.tfvars platforms/metal-livecd
terraform apply -var-file=./build/my-cluster/terraform.tfvars platforms/metal-livecd
```

- After running terraform apply, matchbox-provider will generate files in matchbox container through gRPC and terraform will waiting until ssh connection to the target success to generate tls stuff for etcd into etcd node. Then it will need to reboot all target nodes.
- tectonic_experimental needs to be set true, for self-signed tls.

- After PXE booting finishes successfully, each node will make http request to the following url which
 is set in kernel parameter(cloud-config), and they will acquire the following ignition json data.

```
URL) http://matchbox.example.com:8080/ignition?uuid=81ffc8c0-e499-11e3-bc05-c45444d38579&mac=c4-54-44-d3-85-78
```

This ignition has a role to make systemd unit to make bash script as '/opt/installer' and run this. In '/opt/installer' scripts will fetch ignition json for coreos installation from matchbox server, and will run coreos-install command with it. After running coreos-install, scripts will run udevadm, finally reboot the node.  

```
{
  "ignition": {
    "version": "2.0.0",
    "config": {}
  },
  "storage": {
    "files": [
      {
        "filesystem": "root",
        "path": "/opt/installer",
        "contents": {
          "source": "data:,%23!%2Fbin%2Fbash%20-ex%0Acurl%20%22http%3A%2F%2Fmatchbox.example.com%3A8080%2Fignition%3Fuuid%3D81ffc8c0-e499-11e3-bc05-c45444d38579%26mac%3Dc4-54-44-d3-85-78%26os%3Dinstalled%22%20-o%20ignition.json%0Acoreos-install%20-d%20%2Fdev%2Fsda%20-C%20stable%20-V%201520.8.0%20-i%20ignition.json%20-b%20http%3A%2F%2Fmatchbox.example.com%3A8080%2Fassets%2Fcoreos%0Audevadm%20settle%0Asystemctl%20reboot%0A",
          "verification": {}
        },
        "mode": 320,
        "user": {},
        "group": {}
      }
    ]
  },
  "systemd": {
    "units": [
      {
        "name": "installer.service",
        "enable": true,
        "contents": "[Unit]\nRequires=network-online.target\nAfter=network-online.target\n[Service]\nType=simple\nExecStart=/opt/installer\n[Install]\nWantedBy=multi-user.target\n"
      }
    ]
  },
  "networkd": {},
  "passwd": {
    "users": [
      {
        "name": "debug",
        "sshAuthorizedKeys": [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKWRNQ2dy+5mN4pZ12XNYihVb4Du15akiKot1XR8j8qshox74ROex3QTR9FDa97sfYLNhKRm4SQAxSPW4HrnXZU1Qnc4YcakxhVs4vFOCKocesE34E6kddcX1jKjcQjRJf5M+1D8HhMghguCV4JuPykUNFsX4wQrrPzxRoq99AnCZZnEnq9DZ3T2m903I5aCkB8/GTPhOmnrMIRfKLZX+BK3pXniy2rGqqGS/lZ3RG45PvtWfJ4qFs1uiipy4ODbiNHJVmn7G3Eo3c9qIZcc6XLY6G6ZgmNKyhDpCpFDZE/RqCBgqrKJDwrk5NHKAkqy6CXMjmDG/3v8OvQuS0po95 ocp@ocpui"
        ],
        "create": {
          "groups": [
            "sudo",
            "docker"
          ]
        }
      }
    ]
  }
}
```


To retrieve ingnition json for installtion can be retrieved by the following URL.  
```
http://10.10.10.120:8080/ignition?uuid=81ffc8c0-e499-11e3-bc05-c45444d38579&mac=c4-54-44-d3-85-78&os=installed
```

Ignition json as an argument of coreos-install is like following.  

```
{
  "ignition": {
    "version": "2.0.0",
    "config": {}
  },
  "storage": {
    "files": [
      {
        "filesystem": "root",
        "path": "/etc/kubernetes/installer/kubelet.env",
        "contents": {
          "source": "data:,KUBELET_IMAGE_URL%3D%22quay.io%2Fcoreos%2Fhyperkube%22%0AKUBELET_IMAGE_TAG%3D%22v1.7.5_coreos.1%22%0A",
          "verification": {}
        },
        "mode": 420,
        "user": {},
        "group": {}
      },
      {
        "filesystem": "root",
        "path": "/etc/hostname",
        "contents": {
          "source": "data:,node3.example.com",
          "verification": {}
        },
        "mode": 420,
        "user": {},
        "group": {}
      },
      {
        "filesystem": "root",
        "path": "/etc/sysctl.d/max-user-watches.conf",
        "contents": {
          "source": "data:,fs.inotify.max_user_watches%3D16184%0A",
          "verification": {}
        },
        "mode": 420,
        "user": {},
        "group": {}
      }
    ]
  },
  "systemd": {
    "units": [
      {
        "name": "docker.service",
        "enable": true,
        "dropins": [
          {
            "name": "10-dockeropts.conf",
            "contents": "[Service]\nEnvironment=\"DOCKER_OPTS=--log-opt max-size=50m --log-opt max-file=3\"\n"
          }
        ]
      },
      {
        "name": "locksmithd.service",
        "mask": true
      },
      {
        "name": "wait-for-dns.service",
        "enable": true,
        "contents": "[Unit]\nDescription=Wait for DNS entries\nWants=systemd-resolved.service\nBefore=kubelet.service\n[Service]\nType=oneshot\nRemainAfterExit=true\nExecStart=/bin/sh -c 'while ! /usr/bin/grep '^[^#[:space:]]' /etc/resolv.conf > /dev/null; do sleep 1; done'\n[Install]\nRequiredBy=kubelet.service\n"
      },
      {
        "name": "k8s-node-bootstrap.service",
        "enable": true,
        "contents": "[Unit]\nDescription=Bootstrap Kubernetes Node Components\nConditionPathExists=!/etc/kubernetes/kubelet.env\nBefore=kubelet.service\n\n[Service]\nType=simple\nRemainAfterExit=true\nRestart=on-failure\nRestartSec=10\nTimeoutStartSec=1h\nExecStartPre=/usr/bin/mkdir -p /etc/kubernetes\n\nExecStartPre=/usr/bin/docker run --rm \\\n            --tmpfs /tmp \\\n            -v /usr/share:/usr/share:ro \\\n            -v /usr/lib/os-release:/usr/lib/os-release:ro \\\n            -v /usr/share/ca-certificates/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro \\\n            -v /var/lib/torcx:/var/lib/torcx \\\n            -v /var/run/dbus:/var/run/dbus \\\n            -v /run/metadata:/run/metadata:ro \\\n            -v /run/torcx:/run/torcx:ro \\\n            -v /run/systemd:/run/systemd \\\n            -v /etc/coreos:/etc/coreos:ro \\\n            -v /etc/torcx:/etc/torcx \\\n            -v /etc/kubernetes:/etc/kubernetes \\\n            quay.io/coreos/tectonic-torcx:installer-latest \\\n            /tectonic-torcx-bootstrap \\\n            --upgrade-os=true \\\n            --torcx-manifest-url=\"\" \\\n            --torcx-skip-setup=false \\\n            --verbose=debug\nExecStart=/usr/bin/echo \"node components bootstrapped\"\n\n[Install]\nWantedBy=multi-user.target kubelet.service\n"
      },
      {
        "name": "kubelet.service",
        "enable": true,
        "contents": "[Unit]\nDescription=Kubelet via Hyperkube ACI\n\n[Service]\nEnvironmentFile=/etc/kubernetes/kubelet.env\nEnvironment=\"RKT_RUN_ARGS=--uuid-file-save=/var/cache/kubelet-pod.uuid \\\n  --volume=resolv,kind=host,source=/etc/resolv.conf \\\n  --mount volume=resolv,target=/etc/resolv.conf \\\n  --volume var-lib-cni,kind=host,source=/var/lib/cni \\\n  --mount volume=var-lib-cni,target=/var/lib/cni \\\n  --volume var-log,kind=host,source=/var/log \\\n  --mount volume=var-log,target=/var/log\"\n\nExecStartPre=/bin/mkdir -p /etc/kubernetes/manifests\nExecStartPre=/bin/mkdir -p /srv/kubernetes/manifests\nExecStartPre=/bin/mkdir -p /etc/kubernetes/checkpoint-secrets\nExecStartPre=/bin/mkdir -p /etc/kubernetes/cni/net.d\nExecStartPre=/bin/mkdir -p /var/lib/cni\n\nExecStartPre=/usr/bin/bash -c \"grep 'certificate-authority-data' /etc/kubernetes/kubeconfig | awk '{print $2}' | base64 -d > /etc/kubernetes/ca.crt\"\nExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/cache/kubelet-pod.uuid\n\nExecStart=/usr/lib/coreos/kubelet-wrapper \\\n  --kubeconfig=/etc/kubernetes/kubeconfig \\\n  --require-kubeconfig \\\n  --cni-conf-dir=/etc/kubernetes/cni/net.d \\\n  --network-plugin=cni \\\n  --lock-file=/var/run/lock/kubelet.lock \\\n  --exit-on-lock-contention \\\n  --pod-manifest-path=/etc/kubernetes/manifests \\\n  --allow-privileged \\\n  --node-labels=node-role.kubernetes.io/node \\\n   \\\n   \\\n  --minimum-container-ttl-duration=6m0s \\\n  --cluster-dns=10.3.0.10 \\\n  --cluster-domain=cluster.local \\\n  --client-ca-file=/etc/kubernetes/ca.crt \\\n   \\\n   \\\n  --anonymous-auth=false\n\nExecStop=-/usr/bin/rkt stop --uuid-file=/var/cache/kubelet-pod.uuid\n\nRestart=always\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target\n"
      }
    ]
  },
  "networkd": {},
  "passwd": {
    "users": [
      {
        "name": "core",
        "sshAuthorizedKeys": [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKWRNQ2dy+5mN4pZ12XNYihVb4Du15akiKot1XR8j8qshox74ROex3QTR9FDa97sfYLNhKRm4SQAxSPW4HrnXZU1Qnc4YcakxhVs4vFOCKocesE34E6kddcX1jKjcQjRJf5M+1D8HhMghguCV4JuPykUNFsX4wQrrPzxRoq99AnCZZnEnq9DZ3T2m903I5aCkB8/GTPhOmnrMIRfKLZX+BK3pXniy2rGqqGS/lZ3RG45PvtWfJ4qFs1uiipy4ODbiNHJVmn7G3Eo3c9qIZcc6XLY6G6ZgmNKyhDpCpFDZE/RqCBgqrKJDwrk5NHKAkqy6CXMjmDG/3v8OvQuS0po95 ocp@ocpui"
        ]
      }
    ]
  }
}
```
