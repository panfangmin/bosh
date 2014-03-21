ubuntu:
  user.present:
    - remove_groups: False
    - groups:
      - sudo
