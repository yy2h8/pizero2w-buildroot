# Development environment
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
export EDITOR=vi
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# UTF-8 locale support
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Python environment
export PYTHONSTARTUP=~/.pythonrc
export PYTHONDONTWRITEBYTECODE=1
export PIP_DEFAULT_TIMEOUT=60

# SSL certificates for HTTPS
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Aliases
alias python=python3
alias pip='python3 -m pip'
