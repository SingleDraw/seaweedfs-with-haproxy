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

    # Define stick-table for tracking IP request rate and auth failures
    stick-table type ip size 1m expire 10m store gpc0,gpc0_rate(10s)

    # Track source IP in stick-table
    http-request track-sc0 src

    # Authentication ACL
    acl valid_auth http_auth(users)
    
    # Check if too many auth failures from this IP
    acl too_many_auth_fail sc0_gpc0_rate gt 3

    # Deny if too many auth failures
    http-request deny if too_many_auth_fail

    # Increment counter on auth failure (when auth is required but not valid)
    http-request sc-inc-gpc0(0) if !valid_auth

    # Ask for auth if not valid
    http-request auth realm SeaweedFS if !valid_auth

    default_backend seaweedfs_filer

backend seaweedfs_filer
    mode http
    server filer1 sfs_filer:8899 check

userlist users
    user $HAPROXYUSER insecure-password $HAPROXYPASSWORD
EOF
umask 022

# Start haproxy with the config file
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg -db
