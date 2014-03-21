runit:
  pkg:
    - installed

runsvdir:
  service:
    - running
    - require:
      - pkg: runit
