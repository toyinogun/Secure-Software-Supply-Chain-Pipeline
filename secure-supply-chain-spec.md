# Technical Specification: Secure Software Supply Chain Pipeline

## 1. Executive Summary
This project aims to implement a NIST-compliant **Secure Software Supply Chain** pipeline. It demonstrates an automated, end-to-end workflow for building, securing, and deploying containerized applications. The core objective is to prevent unverified or vulnerable code from running in production by enforcing **image signing** and **vulnerability scanning** gates.

**Goal**: Build -> Scan -> Sign -> Enforce.

## 2. Architecture Overview

### 2.1 Components
*   **Source Code Management**: GitHub (App Repo & Config Repo)
*   **CI Pipeline**: GitHub Actions
*   **CD Controller**: ArgoCD (GitOps)
*   **Container Registry**: GitHub Container Registry (GHCR)
*   **Security Scanner**: Trivy (Aqua Security)
*   **Signing Authority**: Cosign (Sigstore / Keyless)
*   **Kubernetes Cluster**: Existing Cluster
*   **Policy Engine**: Kyverno (Admission Controller)

### 2.2 Workflow
1.  **Commit**: Developer pushes application code to `main` (App Repo).
2.  **Build**: GitHub Actions compiles a Go API and builds a **Distroless** Docker image (Multi-stage).
3.  **Scan**: Trivy scans the artifact for CVEs (Common Vulnerabilities and Exposures).
    *   *Gate*: Pipeline fails if `CRITICAL` vulnerabilities are found.
4.  **Publish**: Image is pushed to GHCR (`ghcr.io/toyin/secure-api`).
5.  **Sign**: Cosign uses OIDC (Keyless signing) to sign the image digest in the registry.
6.  **Update Manifest**: The CI pipeline commits the new image tag (SHA digest) to the **GitOps Config Repo** (or updates the `values.yaml`).
7.  **Sync**: ArgoCD detects the change in the Config Repo and syncs the new deployment to the cluster.
8.  **Verify & Enforce**:
    *   Kyverno (Admission Controller) intercepts the deployment request.
    *   It validates the image signature against the public key/identity.
    *   If valid: Pod is started.
    *   If invalid/unsigned: Deployment is blocked.

## 3. Implementation Details

### 3.1 The Application (Target Workload)
A minimal, secure Golang web service.
*   **Language**: Go 1.22+
*   **Endpoint**: `GET /` -> `{"status": "secure", "version": "1.0.0"}`
*   **Base Image**: `gcr.io/distroless/static:nonroot`
    *   *Why*: No shell, no package manager, non-root user by default. Small attack surface.

### 3.2 The Pipeline (GitHub Actions)
**Workflow File**: `.github/workflows/supply-chain.yaml`

**Jobs**:
1.  **Test**: `go test ./...`
2.  **Build-Scan-Push-Sign**:
    *   **Docker Build**: Build image locally.
    *   **Trivy Scan**:
        ```bash
        trivy image --exit-code 1 --severity CRITICAL my-image
        ```
    *   **Login**: Authenticate to GHCR.
    *   **Push**: Upload image.
    *   **Cosign Sign**:
        ```bash
        cosign sign --yes ghcr.io/user/repo:tag
        ```

### 3.3 The Policy (Kyverno)
**Resource**: `ClusterPolicy`
**Rule**: `check-image-signature`
*   **Match**: All pods in namespace `secure-apps`.
*   **Verify**: Check that images coming from `ghcr.io/toyin/*` are signed by the GitHub Actions OIDC identity.

## 4. Success Criteria (Definition of Done)
1.  [ ] **Repo Created**: Contains Go app, Dockerfile, and K8s manifests.
2.  [ ] **Pipeline Green**: GitHub Actions successfully builds, scans, pushes, and signs.
3.  [ ] **Scanning Works**: Introduce a vulnerable dependency (or base image) and verify pipeline FAILS.
4.  [ ] **Signing Works**: Verify signature manually with `cosign verify`.
5.  [ ] **Enforcement Works**:
    *   Deploying the signed image -> **SUCCESS**.
    *   Deploying `nginx:latest` (unsigned) to the protected namespace -> **BLOCKED** by Kyverno.

## 5. Prerequisites
*   GitHub Account
*   Kubernetes Cluster (running)
*   `kubectl` and `helm` installed locally.
