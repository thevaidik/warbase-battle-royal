import subprocess, sys, time, json, urllib.request, urllib.error

D = ['docker', 'exec', 'portainer_docker_1', 'docker', '-H', 'unix:///data/docker.sock']
IMAGE = 'warbase-colyseus:release-20261120-map-opt'
CONTAINER_NAME = 'warbase-colyseus-candidate'
BACKUP_NAME = 'warbase-colyseus-backup-pre-map-opt-20261120'
STAGE_NAME = 'warbase-colyseus-stage-map-opt'

def run(*args, check=True):
    res = subprocess.run(D + list(args), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if check and res.returncode != 0:
        raise RuntimeError(f"Command failed ({res.returncode}): {' '.join(args)}\n{res.stdout}")
    return res.stdout

def get(url, timeout=5, method='GET', headers=None):
    req = urllib.request.Request(
        url,
        data=b'{}' if method == 'POST' else None,
        method=method,
        headers={'User-Agent': 'deploy-release/1.0', **(headers or {})}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()

def wait_healthy(url, max_attempts=60, delay=1.0):
    for i in range(max_attempts):
        try:
            code, body = get(url)
            if code == 200:
                return code, body
        except Exception:
            pass
        time.sleep(delay)
    raise RuntimeError(f"Health check timed out after {max_attempts} attempts: {url}")

def stage():
    print("=== STEP 1: Staging check ===", flush=True)
    run('rm', '-f', STAGE_NAME, check=False)
    
    run('run', '-d', '--name', STAGE_NAME,
        '--network', 'warbase_server_default',
        '--restart=no',
        '-p', '100.107.118.10:18083:8081',
        '-e', 'ADMISSION_TRUSTED_PROXY_CIDRS=100.107.118.10/32',
        '-e', 'PUBLIC_ADDRESS=127.0.0.1:18083',
        '-e', 'ADMIN_TAILNET_HTTP=1',
        '-e', 'HOST=0.0.0.0',
        '-e', 'PORT=8081',
        '-e', 'NODE_ENV=production',
        '-e', 'STATIC_DIR=/app/static',
        '-e', 'ENABLE_PRIVATE_ADMIN=0',
        '-e', 'ENABLE_PRIVATE_MONITOR=0',
        '-e', 'ADMISSION_JWT_SECRET_FILE=/run/secrets/admission/jwt',
        '-e', 'ADMISSION_GATEWAY_SECRET_FILE=/run/secrets/gateway/token',
        '-v', 'warbase-admission-secrets:/run/secrets/admission:ro',
        '-v', 'warbase-gateway-secrets:/run/secrets/gateway:ro',
        '-v', '/data/warbase-colyseus-ops-token:/run/secrets/ops_metrics_token:ro',
        IMAGE)
    
    print("Staging container launched. Probing http://100.107.118.10:18083/health...", flush=True)
    code, body = wait_healthy('http://100.107.118.10:18083/health')
    print(f"Staging health check passed: {body.decode()}", flush=True)
    
    code, body = wait_healthy('http://100.107.118.10:18083/')
    if code != 200 or b'html' not in body.lower():
        raise RuntimeError(f"Staging web client check failed: code {code}, body len {len(body)}")
    print("Staging web client check passed.", flush=True)
    
    run('rm', '-f', STAGE_NAME)
    print("Staging container cleaned up. STAGE_OK", flush=True)

def rollback():
    print("=== ROLLBACK INITIATED ===", flush=True)
    try:
        run('rm', '-f', CONTAINER_NAME, check=False)
        run('rename', BACKUP_NAME, CONTAINER_NAME)
        run('update', '--restart=unless-stopped', CONTAINER_NAME)
        run('start', CONTAINER_NAME)
        wait_healthy('http://100.107.118.10:8082/health')
        print("Rollback successful: original container restored.", flush=True)
    except Exception as e:
        print(f"FATAL: Rollback error: {e}", flush=True)
        raise

def promote():
    print("=== STEP 2: Promotion / Cutover ===", flush=True)
    run('rm', '-f', BACKUP_NAME, check=False)
    
    print(f"Stopping {CONTAINER_NAME}...", flush=True)
    run('update', '--restart=no', CONTAINER_NAME)
    run('stop', '-t', '15', CONTAINER_NAME)
    run('rename', CONTAINER_NAME, BACKUP_NAME)
    print(f"Renamed {CONTAINER_NAME} to {BACKUP_NAME}", flush=True)
    
    try:
        print(f"Launching new {CONTAINER_NAME} with image {IMAGE}...", flush=True)
        run('run', '-d', '--name', CONTAINER_NAME,
            '--restart=unless-stopped',
            '--network', 'warbase_server_default',
            '--network-alias', CONTAINER_NAME,
            '-p', '100.107.118.10:8082:8081',
            '-e', 'ADMISSION_TRUSTED_PROXY_CIDRS=100.107.118.10/32',
            '-e', 'PUBLIC_ADDRESS=war.vaidik.blog/colyseus',
            '-e', 'ADMIN_TAILNET_HTTP=1',
            '-e', 'HOST=0.0.0.0',
            '-e', 'PORT=8081',
            '-e', 'NODE_ENV=production',
            '-e', 'STATIC_DIR=/app/static',
            '-e', 'ENABLE_PRIVATE_ADMIN=1',
            '-e', 'ENABLE_PRIVATE_MONITOR=1',
            '-e', 'ADMIN_SESSION_SECRET_FILE=/run/secrets/admin/session',
            '-e', 'ADMIN_DATABASE_PATH=/app/admin-data/operations.sqlite',
            '-e', 'ADMIN_JWT_SECRET_FILE=/run/secrets/admin/jwt',
            '-e', 'ADMISSION_JWT_SECRET_FILE=/run/secrets/admission/jwt',
            '-e', 'ADMISSION_GATEWAY_SECRET_FILE=/run/secrets/gateway/token',
            '-e', 'OPS_METRICS_TOKEN_FILE=/run/secrets/ops_metrics_token',
            '-v', 'warbase-admin-data:/app/admin-data',
            '-v', 'warbase-gateway-secrets:/run/secrets/gateway:ro',
            '-v', 'warbase-admission-secrets:/run/secrets/admission:ro',
            '-v', 'warbase-admin-secrets:/run/secrets/admin:ro',
            '-v', '/data/warbase-colyseus-ops-token:/run/secrets/ops_metrics_token:ro',
            IMAGE)
            
        print("Probing health on http://100.107.118.10:8082/health...", flush=True)
        code, body = wait_healthy('http://100.107.118.10:8082/health')
        print(f"Production container healthy! Response: {body.decode()}", flush=True)
        
        # Verify Gateway health
        print("Probing gateway on http://127.0.0.1:8081/health...", flush=True)
        g_code, g_body = wait_healthy('http://127.0.0.1:8081/health')
        print(f"Gateway healthy! Response: {g_body.decode()}", flush=True)
        
        print("PROMOTION_SUCCESSFUL", flush=True)
        
    except Exception as e:
        print(f"Production launch failed: {e}. Triggering rollback...", flush=True)
        rollback()
        raise RuntimeError(f"Promotion failed and rolled back: {e}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd == "stage":
        stage()
    elif cmd == "promote":
        promote()
    elif cmd == "rollback":
        rollback()
    elif cmd == "all":
        stage()
        promote()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
