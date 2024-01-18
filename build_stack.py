import requests
import json

def fetch_ip_ranges(url):
    try:
        response = requests.get(url)
        response.raise_for_status()  # Check if the request was successful
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching IP ranges from {url}: {e}")
        return None

def process_cloudflare(url, key=[]):
    ip_ranges = fetch_ip_ranges(url)
    return list(set(f'{cidr}' for cidr in ip_ranges.get("result", {}).get("ipv4_cidrs", [])))

def process_google(url, key=[]):
    ip_ranges = fetch_ip_ranges(url)
    return [prefix['ipv4Prefix'] for prefix in ip_ranges.get("prefixes", {}) if 'ipv4Prefix' in prefix]

def process_amazon(url, key=[]):
    ip_ranges = fetch_ip_ranges(url)
    return [prefix['ip_prefix'] for prefix in ip_ranges.get("prefixes", {}) if 'ip_prefix' in prefix and ("service" not in prefix or prefix["service"] == "S3") and ("region" not in prefix or prefix["region"] in key)]

if __name__ == "__main__":
    cloudflare_ips = process_cloudflare("https://api.cloudflare.com/client/v4/ips")
    google_ips = process_google("https://www.gstatic.com/ipranges/goog.json")
    amazon_us_ips = process_amazon("https://ip-ranges.amazonaws.com/ip-ranges.json", ["us-east-1","us-east-2","us-west-1","us-west-2"])

    hcl_data = f'''
locals {{
  dns_names = toset(["container-registry.oracle.com", "registry.k8s.io", "quay.io", "cdn.quay.io", "cdn01.quay.io", "cdn02.quay.io", "cdn03.quay.io"])
  worker_egress_cidr = {{
    "akamai" = ["23.0.0.0/12", "23.32.0.0/11", "104.64.0.0/10"]
    // https://www.cloudflare.com/ips-v4/#
    "cloudflare" = {json.dumps(cloudflare_ips)}
    // https://www.gstatic.com/ipranges/goog.json
    "google" = {json.dumps(google_ips)}
    // https://docs.aws.amazon.com/vpc/latest/userguide/aws-ip-ranges.html
    "amazon_us" = {json.dumps(amazon_us_ips)}
  }}
}}'''

with open('locals_restricted.tf', 'w') as file:
    # Write the variable value to the file
    file.write(hcl_data)