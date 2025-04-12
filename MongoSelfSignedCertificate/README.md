# MongoDB SSL/TLS Certificate Generator

This project provides scripts to automate the generation of SSL/TLS certificates for MongoDB clusters with proper Subject Alternative Names (SANs) for secure communication between nodes.

## Prerequisites

- OpenSSL 1.1.1 or newer
- Bash shell
- SSH access to remote MongoDB nodes (if distributing certs)
- Proper permissions to create/read certificate files

## Files

- `mongo-cert-vars.sh` - OpenSSL configuration template
- `generate-cert.sh` - Main certificate generation script

## Installation

1. Clone this repository or download the files
2. Make the script executable:
   ```bash
   chmod +x generate-cert.sh
   ```

## Usage

### Basic Certificate Generation

```bash
./generate-cert.sh
```

The script will prompt you for:
1. Certificate base name (without extensions)
2. Up to 5 DNS names for the certificate
3. Up to 3 server IP addresses for certificate distribution

### Advanced Options

You can modify the `mongo-cert-vars.sh` file directly to change:
- Default certificate attributes (country, organization, etc.)
- Key size (currently 4096 bits)
- Certificate validity period (currently 730 days/2 years)
- Extended key usage parameters

### Certificate Distribution

The script will automatically:
1. Generate the certificate files (.crt, .key, .pem)
2. Store them in a timestamped directory under `/tmp`
3. Copy them to remote servers if IP addresses are provided

## Output Files

For a certificate named `mongodb`, the script generates:
- `mongodb.crt` - The certificate file
- `mongodb.key` - The private key file
- `mongodb.pem` - Combined PEM file (key + certificate)