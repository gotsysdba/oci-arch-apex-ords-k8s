import requests, json, shutil, tempfile, os, sys, glob
max_stack_size_mb = 11

def exclusion_files():
    """Returns a callable which will exclude files from being copied."""
    patterns = set(
        [
            "terraform.*", ".terraform*", "*.pem", "*.zip", ".config", ".venv", ".cache", "Wallet_*.zip",
            ".git*", "stack", "stage", "tmp", "Jenkinsfile", "backend.conf", "backend.tf", "schema.yaml.tmpl",
            "kubeconfig", "*.md", "*.adoc", "*.png", "kaniko.tar.gz", ".idea", ".vscode", "__pycache__",
            "vs-code-ext", "smoke-test"
        ]
    )
    return shutil.ignore_patterns(*patterns)

def build_stack(src_dir, dst_dir):
    """Perform file modifications and build stack zip file
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        build_dir = os.path.join(tmpdir, 'build')
        print(f'Copying {src_dir} to {build_dir}')
        shutil.copytree(src_dir, build_dir, ignore=exclusion_files())

        # Remove local vars/main.yaml and vars/*.yaml files
        for file in glob.glob(os.path.join(build_dir, 'ansible', 'roles', '*', 'vars', 'main.*'), recursive=True):
            os.remove(file)
        for file in glob.glob(os.path.join(build_dir, 'ansible', 'vars', '*.yaml'), recursive=True):
            os.remove(file)

        # Remove helm charts
        for dir in glob.glob(os.path.join(build_dir, 'kubernetes', 'deployments', '*', '*', 'base', 'charts'), recursive=False):
            shutil.rmtree(dir)
        # Remove manifests dirs
        try:
            shutil.rmtree(os.path.join(build_dir, 'kubernetes', 'manifests'))
        except FileNotFoundError:
            pass
        # Remove secrets dirs
        try:
            shutil.rmtree(os.path.join(build_dir, 'kubernetes', 'secrets'))
        except FileNotFoundError:
            pass

        # Remove the sbin directory
        shutil.rmtree(os.path.join(build_dir, 'sbin'), ignore_errors=True)

        # All Assets Moved, rm dir
        shutil.rmtree(os.path.join(build_dir, 'assets'))
        # Create the Stack
        stack_name = os.path.join(dst_dir, 'oci-arch-apex-ords-k8s')
        print(f'Creating {stack_name}.zip from {build_dir}')
        shutil.make_archive(stack_name, 'zip', build_dir)

    if not os.path.exists(stack_name+'.zip'):
        shutil.rmtree(build_dir)
        sys.exit('Unable to build the stack archive')

    # Check the size < max_stack_size
    stack_file = stack_name+'.zip'
    stack_size_mb = round(os.path.getsize(stack_file)/1048576, 2)
    print(f'Stack File: {stack_file}')
    print(f'Stack Size: {stack_size_mb}M')
    if stack_size_mb > max_stack_size_mb:
        sys.exit(f'Stack is too large {stack_size_mb}M > {max_stack_size_mb}M')

    return stack_file

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

##########################################################################
# MAIN
##########################################################################
def main(args=None):
    project_dir = os.path.dirname(os.path.abspath(os.path.join(sys.argv[0],'../')))
    print(f'Project Directory: {project_dir}')

    cloudflare_ips = process_cloudflare("https://api.cloudflare.com/client/v4/ips")
    google_ips = process_google("https://www.gstatic.com/ipranges/goog.json")
    amazon_us_ips = process_amazon("https://ip-ranges.amazonaws.com/ip-ranges.json", ["us-east-1","us-east-2","us-west-1","us-west-2"])

    hcl_data = f'''
    locals {{
    dns_names = toset(["registry.k8s.io", "quay.io", "cdn.quay.io", "cdn01.quay.io", "cdn02.quay.io", "cdn03.quay.io"])
    worker_egress_cidr = {{
        // https://techdocs.akamai.com/origin-ip-acl/docs/update-your-origin-server (manual)
        "akamai" = ["2.16.0.0/13","23.0.0.0/12","23.192.0.0/11","23.32.0.0/11","23.64.0.0/14","23.72.0.0/13","69.192.0.0/16","72.246.0.0/15","88.221.0.0/16","92.122.0.0/15","95.100.0.0/15","96.16.0.0/15","96.6.0.0/15","104.64.0.0/10","118.214.0.0/16","173.222.0.0/15","184.24.0.0/13","184.50.0.0/15","184.84.0.0/14"]
        // https://www.cloudflare.com/ips-v4/#
        "cloudflare" = {json.dumps(cloudflare_ips)}
        // https://www.gstatic.com/ipranges/goog.json
        "google" = {json.dumps(google_ips)}
        // https://docs.aws.amazon.com/vpc/latest/userguide/aws-ip-ranges.html
        "amazon_us" = {json.dumps(amazon_us_ips)}
    }}
    }}'''

    with open(os.path.join(project_dir,'locals_restricted.tf'), 'w') as file:
        # Write the variable value to the file
        file.write(hcl_data)


    stack_dir = os.path.join(project_dir, 'stack')
    try:
        shutil.rmtree(stack_dir)
    except FileNotFoundError:
        pass

    print(f'Building Stack')
    # Build the Stack
    stack_file = build_stack(project_dir, stack_dir)
    print(f'Stack Built: {stack_file}')

if __name__ == "__main__":
    main(sys.argv[1:])