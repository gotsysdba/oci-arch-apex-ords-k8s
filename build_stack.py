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

def process_prefixes(prefixes, key):
    return list(set(entry.get(key, "") for entry in prefixes if entry.get(key, "") and ("service" not in entry or entry["service"] == "S3") and ("region" not in entry or entry["region"] == "us-east-1")))

def process_cloudflare(ip_ranges):
    return list(set(f'{cidr}' for cidr in ip_ranges.get("result", {}).get("ipv4_cidrs", [])))

def get_ip_ranges(service, key, url):
    ip_ranges = fetch_ip_ranges(url)
    if ip_ranges:
        if service in ["amazon", "google"]:
            return process_prefixes(ip_ranges.get("prefixes", []), key)
        elif service == "cloudflare":
            return process_cloudflare(ip_ranges)
        else:
            print(f"Unsupported service: {service}")
    else:
        print(f"Failed to fetch IP ranges for {service}.")
        return None

if __name__ == "__main__":
    cloudflare = get_ip_ranges("cloudflare", None, "https://api.cloudflare.com/client/v4/ips")
    google = get_ip_ranges("google", "ipv4Prefix", "https://www.gstatic.com/ipranges/goog.json")
    amazon = get_ip_ranges("amazon", "ip_prefix", "https://ip-ranges.amazonaws.com/ip-ranges.json")

    hcl_data = f'''
locals {{
  dns_names = toset(["container-registry.oracle.com", "registry.k8s.io", "quay.io"])
  worker_egress_ip = {{
    "akamai" = ["23.0.0.0/12", "23.32.0.0/11", "104.64.0.0/10"]
    // https://www.cloudflare.com/ips-v4/#
    "cloudflare" = {json.dumps(cloudflare)}
    // https://docs.aws.amazon.com/vpc/latest/userguide/aws-ip-ranges.html
    "amazon" = {json.dumps(amazon)}
    // https://www.gstatic.com/ipranges/goog.json
    "google" = {json.dumps(google)}
  }}
}}'''

with open('locals_restricted.tf', 'w') as file:
    # Write the variable value to the file
    file.write(hcl_data)
