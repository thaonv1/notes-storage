# Hướng dẫn cài đặt Ceph Octopus bằng Ceph Ansible

## 1. Mô hình + IP Plan

- OS: CentOS 8
- Ceph version: Octopus
- Mô hình All-in-one

4 HDD trong đó:

- Mỗi disk có dung lượng 50 GB
- `vda` để cài OS
- `vdb`, `vdc` và `vdd` để làm OSD

Lưu ý: 

Bật firewalld

## 2. Chuẩn bị

Thêm file hosts

```
sudo tee -a /etc/hosts<<EOF
10.10.30.64  cephaio
EOF
```

Update OS

```
sudo dnf update -y
sudo dnf install vim bash-completion tmux -y
```

Cài đặt epel repo

```
sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf config-manager --set-enabled PowerTools
```

Cài đặt git 

```
sudo yum install git vim bash-completion -y
```

Clone repo ansible

```
git clone https://github.com/ceph/ceph-ansible.git
```

Check out sang nhánh của Octopus

```
cd ceph-ansible
git checkout stable-5.0
```

Cài đặt requirement 

```
sudo pip3 install -r requirements.txt
```

Đảm bảo path được add

```
echo "PATH=\$PATH:/usr/local/bin" >>~/.bashrc
source ~/.bashrc
```

Đảm bảo ansible đã được cài đặt

```
ansible --version
```

Gen key

`ssh-keygen`

Copy key sang các node

`ssh-copy-id cephaio`

Chỉnh file config

`vi ~/.ssh/config`

```
Host cephaio
    Hostname 10.10.30.64
    User root
```

## 3. Cấu hình Inventory và Playbook

```
cd ceph-ansible
cp group_vars/all.yml.sample  group_vars/all.yml
```

Chỉnh sửa file `group_vars/all.yml`

```
ceph_release_num: 15
cluster: ceph

# Inventory host group variables
mon_group_name: mons
osd_group_name: osds
rgw_group_name: rgws
mds_group_name: mdss
nfs_group_name: nfss
rbdmirror_group_name: rbdmirrors
client_group_name: clients
iscsi_gw_group_name: iscsigws
mgr_group_name: mgrs
rgwloadbalancer_group_name: rgwloadbalancers
grafana_server_group_name: grafana-server

# Firewalld / NTP
configure_firewall: True
ntp_service_enabled: true
ntp_daemon_type: chronyd

# Ceph packages
ceph_origin: repository
ceph_repository: community
ceph_repository_type: cdn
ceph_stable_release: octopus

# Interface options
monitor_interface: ens3
radosgw_interface: ens3
public_network: 10.10.30.0/24
cluster_network: 10.10.30.0/24

# DASHBOARD
dashboard_enabled: True
dashboard_protocol: http
dashboard_admin_user: admin
dashboard_admin_password: St0ngAdminp@ass

grafana_admin_user: admin
grafana_admin_password: St0ngAdminp@ass
```

Chỉnh sửa file khai báo osd

```
cp group_vars/osds.yml.sample group_vars/osds.yml
vim group_vars/osds.yml
```

```
copy_admin_key: true
devices:
  - /dev/vdb
  - /dev/vdc
  - /dev/vdd
```

Tạo mới file inventory

`vim hosts`

```
# Ceph admin user for SSH and Sudo
[all:vars]
ansible_ssh_user=root
ansible_become=true
ansible_become_method=sudo
ansible_become_user=root

# Ceph Monitor Nodes
[mons]
cephaio

# MDS Nodes
[mdss]
cephaio

# RGW
[rgws]
cephaio

# Manager Daemon Nodes
[mgrs]
cephaio

# set OSD (Object Storage Daemon) Node
[osds]
cephaio

# Grafana server
[grafana-server]
cephaio
```

## 4. Cài đặt ceph octopus

```
cp site.yml.sample site.yml 
ansible-playbook -i hosts site.yml 
```

Kiểm tra sau khi cài đặt xong