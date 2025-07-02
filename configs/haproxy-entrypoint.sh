#!/bin/bash

umask 177
cat <<EOF > /usr/local/etc/haproxy/haproxy.cfg
global
    log stdout format raw local0
    maxconn 2000
    daemon

defaults
    log global
    mode http
    timeout connect 5s
    timeout client 30s
    timeout server 30s

frontend http_front
    bind *:80
    mode http

    stick-table type ip size 1m expire 60s store http_req_rate(60s)
    tcp-request content track-sc0 src
    acl too_many_requests sc_http_req_rate(0) gt 10
    http-request deny status 429 if too_many_requests

    acl valid_auth http_auth(users)
    http-request auth realm SeaweedFS if !valid_auth

    default_backend seaweedfs_filer

backend seaweedfs_filer
    mode http
    server filer1 sfs_filer:8899 check

userlist users
    user $USER insecure-password $PASSWORD
EOF
umask 022

# Start haproxy with the config file
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg -db
