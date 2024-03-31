create_kartaca_user:
  user.present:
    - name: kartaca
    - uid: 2024
    - gid: 2024
    - home: /home/krt
    - shell: /bin/bash
    - password_pillar: kartaca-pillar:kartaca:password
    - require:
      - file: kartaca-pillar.sls

kartaca_sudoers:
  file.append:
    - name: /etc/sudoers
    - text: "kartaca ALL=(ALL) NOPASSWD: /usr/bin/apt"  # Ubuntu'da sudo apt için
    - text: "kartaca ALL=(ALL) NOPASSWD: /usr/bin/yum"  # CentOS'ta sudo yum için
    - require:
      - user: create_kartaca_user

set_timezone_to_istanbul:
  timezone.system:
    - name: Europe/Istanbul

enable_ip_forwarding:
  file.append:
    - name: /etc/sysctl.conf
    - text: "net.ipv4.ip_forward=1"

apply_sysctl_configuration:
  cmd.run:
    - name: sysctl -p /etc/sysctl.conf
    - unless: sysctl -n net.ipv4.ip_forward | grep -q '^1$'

install_required_packages:
  pkg.installed:
{% if grains['os_family'] == 'Debian' %}
    - name: htop
      unless: 'dpkg -l | grep "^ii" | grep -q htop'  # htop paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: sysstat
      unless: 'dpkg -l | grep "^ii" | grep -q sysstat'  # sysstat paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: iputils-tracepath
      unless: 'dpkg -l | grep "^ii" | grep -q iputils-tracepath'  # iputils-tracepath paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: iputils-ping
      unless: 'dpkg -l | grep "^ii" | grep -q iputils-ping'  # iputils-ping paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: dnsutils
      unless: 'dpkg -l | grep "^ii" | grep -q dnsutils'  # dnsutils paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: mtr-tiny
      unless: 'dpkg -l | grep "^ii" | grep -q mtr-tiny'  # mtr-tiny paketinin zaten yüklü olup olmadığını kontrol etmek için
{% elif grains['os_family'] == 'RedHat' %}
    - name: htop
      unless: 'rpm -q htop'  # htop paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: sysstat
      unless: 'rpm -q sysstat'  # sysstat paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: epel-release
      unless: 'rpm -q epel-release'  # epel-release paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: iputils
      unless: 'rpm -q iputils'  # iputils paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: tcptraceroute
      unless: 'rpm -q tcptraceroute'  # tcptraceroute paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: bind-utils
      unless: 'rpm -q bind-utils'  # bind-utils paketinin zaten yüklü olup olmadığını kontrol etmek için
    - name: mtr
      unless: 'rpm -q mtr'  # mtr paketinin zaten yüklü olup olmadığını kontrol etmek için
{% endif %}

hashicorp_repo:
  pkgrepo.managed:
    - humanname: HashiCorp Official Package Repository
    - name: deb https://apt.releases.hashicorp.com {{ grains['oscodename'] }} main
    - dist: {{ grains['oscodename'] }}
    - file: /etc/apt/sources.list.d/hashicorp.list
    - key_url: https://apt.releases.hashicorp.com/gpg

install_terraform:
  pkg.installed:
    - name: terraform=1.6.4
    - fromrepo: hashicorp
    - require:
      - pkgrepo: hashicorp_repo

{% for ip_suffix in range(16) %}
host_entry_{{ ip_suffix }}:
  file.append:
    - name: /etc/hosts
    - text: "192.168.168.{{ 128 + ip_suffix }}/32 kartaca.local"
{% endfor %}

{% if grains['os_family'] == 'RedHat' %}
# Centos özel işlemler
install_nginx:
  pkg.installed:
    - name: nginx

nginx_service_enabled:
  service.enabled:
    - name: nginx
    - require:
      - pkg: install_nginx

# PHP paketlerinin kurulumu
install_php_packages:
  pkg.installed:
    - names:
      - php
      - php-fpm
      - php-mysqlnd
      - php-json
      - php-mbstring
      - php-gd
      - php-xml
      - php-curl

# PHP-FPM servisini başlatma ve otomatik başlatma ayarı
start_php_fpm:
  service.running:
    - name: php-fpm
    - enable: True

# Nginx için PHP konfigürasyon dosyası oluşturma
create_nginx_php_config:
  file.managed:
    - name: /etc/nginx/conf.d/php.conf
    - source: salt://path/to/php.conf
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: install_php_packages
      - service: start_php_fpm

# Nginx servisini yeniden başlatma
restart_nginx:
  service.running:
    - name: nginx
    - watch:
      - file: create_nginx_php_config

download_wordpress:
  cmd.run:
    - name: wget -P /tmp https://wordpress.org/latest.tar.gz

extract_wordpress:
  cmd.run:
    - name: tar -xzf /tmp/latest.tar.gz -C /var/www/wordpress2024 --strip-components=1
    - require:
      - cmd: download_wordpress

{% endif %}