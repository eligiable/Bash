#!/bin/bash

[ req ]
default_bits                   = 2048
default_keyfile                = server-key.pem
distinguished_name             = req_distinguished_name
req_extensions                 = extensions
x509_extensions                = extensions
string_mask                    = utf8only
prompt                         = no
encrypt_key                    = no

[ req_distinguished_name ]
countryName                    = US
stateOrProvinceName            = Pennsylvania
localityName                   = Pittsburgh
organizationName               = GitHub
organizationalUnitName         = Engineering
commonName                     = MongoDB Cluster Certificate
emailAddress                   = admin@example.com

[ extensions ]
basicConstraints               = CA:FALSE
keyUsage                       = digitalSignature, keyEncipherment
extendedKeyUsage               = serverAuth, clientAuth
subjectAltName                 = @alternate_names
nsComment                      = "OpenSSL Generated Certificate"
crlDistributionPoints          = URI:http://crl.example.com/crl.pem

[ alternate_names ]
DNS.1                          = localhost
DNS.2                          = 127.0.0.1
IP.1                           = 127.0.0.1