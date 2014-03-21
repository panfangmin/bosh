{% set goversion = 'go1.2' %}

curl:
  pkg:
    - installed

git:
  pkg:
    - installed

mercurial:
  pkg:
    - installed

make:
  pkg:
    - installed

binutils:
  pkg:
    - installed

bison:
  pkg:
    - installed

gcc:
  pkg:
    - installed

build-essential:
  pkg:
    - installed

gvm:
  cmd.script:
    - source: https://raw.github.com/moovweb/gvm/master/binscripts/gvm-installer
    - user: ubuntu
    - group: ubuntu
    - unless: gvm
    - require:
      - pkg: curl
      - pkg: git
      - pkg: mercurial
      - pkg: make 
      - pkg: binutils
      - pkg: bison
      - pkg: gcc
      - pkg: build-essential
 
install_go:
  cmd.run:
    - name: source $HOME/.gvm/scripts/gvm && gvm install {{ goversion }}
    - unless: source $HOME/.gvm/scripts/gvm && go version | grep {{ goversion }}
    - user: ubuntu
    - group: ubuntu
    - require:
      - cmd: gvm

use_go:
  cmd.run:
    - name: source $HOME/.gvm/scripts/gvm && gvm use {{ goversion }} --default
    - user: ubuntu
    - group: ubuntu
    - require:
      - cmd: install_go

# We have to source gvm in our profile so that the shell created by SSH can use go
/home/ubuntu/.profile:
  file.append: 
    - text: source $HOME/.gvm/scripts/gvm 
