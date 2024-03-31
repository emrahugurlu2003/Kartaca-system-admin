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