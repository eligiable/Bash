#!/bin/bash
[ req ]
#default_bits                   = 2048
#default_keyfile                = server-key.pem
distinguished_name              = req_distinguished_name
req_extensions                  = extensions
x509_extensions                 = extensions
#string_mask                    = utf8only

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_default             = US
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = PA
localityName                    = Locality Name (eg, city)
localityName_default            = Pittsburgh
organizationName                = Organization Name (eg, company)
organizationName_default        = github
commonName                      = Common Name (e.g. server FQDN or YOUR name)
commonName_default              = DNS1
emailAddress                    = Email Address
emailAddress_default            =

[ extensions ]
#subjectKeyIdentifier           = hash
#authorityKeyIdentifier         = keyid,issuer
basicConstraints                = CA:TRUE
#keyUsage                       = nonRepudiation, digitalSignature, keyEncipherment
#extendedKeyUsage               = serverAuth
subjectAltName                  = @alternate_names
nsComment                       = "eligiable Generated Certificate"

[ alternate_names ]
DNS.1                           = DNS1
DNS.2                           = DNS2
DNS.3                           = DNS3
DNS.4                           = DNS4
DNS.5                           = DNS5
