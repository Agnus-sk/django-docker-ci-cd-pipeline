# DevOps Implementation Documentation

This document describes the DevOps workflow followed to containerize and
prepare a full-stack application for deployment. It focuses on practical
steps, real issues encountered, and how they were resolved.

---

## Step 0: Project Understanding and Local Setup

### Project Overview

The project consists of:
- Backend: Django (API-based)
- Frontend: React (Vite + TypeScript)

Before introducing Docker or automation tools, the application was first
understood and verified locally.

---

### Backend Local Setup

Steps performed:
- Navigated to the backend directory
- Created and activated a Python virtual environment
- Installed required dependencies
- Started the Django development server

Command used:
```bash
python manage.py runserver
```

Observations:
- Backend server started on `http://127.0.0.1:8000`
- The root URL (`/`) returned a 404 response, which is expected for an API-only backend
- The valid API endpoint was confirmed at `/api/hello/`

---

### Dependency Resolution

While starting the backend locally, missing dependencies were encountered.

Issues faced:
- ModuleNotFoundError: No module named 'django'
- ModuleNotFoundError: No module named 'corsheaders'

Resolution:
- Installed missing dependencies using pip
- Generated a dependency file using:
```bash
pip freeze > requirements.txt
```

This ensured all required dependencies were captured for Docker and CI/CD.

---

### Database Initialization

The backend reported unapplied database migrations during startup.

Resolution:
```bash
python manage.py migrate
```

This initialized the default Django database schema.

---

## Step 1: Backend Dockerization

### Objective

The goal of this step was to containerize the Django backend so it can run
consistently across different environments without relying on the host
system configuration.

---

### Dockerfile Creation

A Dockerfile was created with the following considerations:
- Used a minimal Python base image
- Installed dependencies using requirements.txt
- Ran the application as a non-root user
- Exposed port 8000 for API access

The backend container was configured to run using:
```bash
python manage.py runserver 0.0.0.0:8000
```

Binding to 0.0.0.0 allows the container to accept external connections.

---

### Docker Build Issue: Missing requirements.txt

Initial Docker builds failed because requirements.txt was not present
in the Docker build context.

Resolution:
- Generated the file using pip freeze
- Corrected a file naming issue (requirement.txt → requirements.txt)
- Re-ran the Docker build

---

### Docker Build Issue: Network and DNS Failures

During Docker image builds, package installation failed due to DNS
resolution issues inside Docker.

Errors observed:
- Temporary failure in name resolution
- apt-get unable to reach Debian repositories
- pip install unable to reach PyPI

These issues were caused by Docker Desktop networking limitations on
Fedora and restricted DNS resolution during image builds.

---

### Offline Dependency Installation Solution

To resolve persistent network issues, an offline dependency installation
strategy was implemented.

Steps followed:
```bash
pip download -r requirements.txt -d wheels
```

```bash
pip install --no-index --find-links=/wheels -r requirements.txt
```

This approach allowed Docker images to be built without requiring
internet access during the build process.

---

### Backend Container Verification

After a successful Docker build:
```bash
docker run -p 8000:8000 django-backend
```

The API endpoint /api/hello/ responded correctly in the browser,
confirming the backend was running inside a Docker container.

---

## Key Learnings

- Docker containers run in isolated environments independent of the host OS
- Network and DNS issues are common in real-world Docker setups
- Offline dependency installation is a valid DevOps solution
- Clear documentation of issues and resolutions improves maintainability

---

## Next Steps

- Dockerize the frontend (React)
- Use Docker Compose for multi-container setup
- Implement CI/CD using GitHub Actions
- Provision infrastructure using Terraform

---

## Conclusion

The Django backend was successfully containerized while handling real
infrastructure challenges. The backend is now portable, reproducible,
and ready for integration into a complete DevOps pipeline.



## Step 2: Frontend Dockerization

### Objective

The objective of this step was to containerize the React frontend so it
can run independently inside Docker, without relying on a locally
installed Node.js environment.

---

### Frontend Overview

The frontend is built using:
- React
- Vite
- TypeScript

In local development, the application runs using the Vite development
server. For Dockerization, the frontend is built into static assets and
served using nginx.

---

### Dockerization Approach

A multi-stage Docker build was used:

- **Build stage**:
  - Used a Node.js base image
  - Installed frontend dependencies
  - Built the production-ready static files

- **Runtime stage**:
  - Used an nginx base image
  - Served the built static files efficiently

This approach keeps the final image lightweight and production-ready.

---

### Dockerfile Implementation

The frontend Dockerfile:
- Uses `node:20-alpine` to build the application
- Runs `npm install` to install dependencies
- Runs `npm run build` to generate static files
- Uses `nginx:alpine` to serve the final build
- Exposes port 80 for HTTP access

---

### Docker Build Issue: Missing TypeScript

During the initial Docker build, the following error was encountered:

- `tsc: not found`

Root cause:
- TypeScript was used in the build process but was not listed as a project
  dependency.

Resolution:
- Added TypeScript as a development dependency in `package.json`
- Rebuilt the Docker image successfully

This ensured the build process worked consistently inside Docker.

---

### Frontend Container Verification

After a successful Docker build:
- The frontend container was started using:
```bash
docker run -p 3000:80 react-frontend


---

## Docker Compose Integration

After successfully containerizing the backend and frontend individually,
the next step was to orchestrate both services together using Docker Compose.

### docker-compose.yml Structure

- Defined two services:
  - `backend`
  - `frontend`
- Each service:
  - Uses its respective build context
  - Exposes necessary ports
  - Uses Docker Hub image naming format

Example structure:

```yaml
services:
  backend:
    build:
      context: ./backend
    image: ${DOCKER_USERNAME}/django-backend:latest
    ports:
      - "8000:8000"
    environment:
      - ALLOWED_HOSTS=*

  frontend:
    build:
      context: ./frontend
    image: ${DOCKER_USERNAME}/django-frontend:latest
    ports:
      - "3000:3000"
    depends_on:
      - backend
```

This allowed both services to run together using:

```bash
docker compose up -d
```

---

## CI Pipeline Setup (GitHub Actions)

A CI/CD workflow was created inside:

```
.github/workflows/ci.yml
```

### Workflow Triggers

- On push to `main`
- On pull request to `main`

### CI Stages

1. Checkout repository
2. Set up Docker Buildx
3. Login to Docker Hub
4. Build Docker images
5. Push images to Docker Hub
6. Deploy to AWS EC2 via SSH

---

## Docker Hub Integration

To enable automated image storage:

- Created Docker Hub repositories:
  - `django-backend`
  - `django-frontend`

- Added GitHub Secrets:
  - `DOCKER_USERNAME`
  - `DOCKER_PASSWORD`

Images are tagged as:

```
${DOCKER_USERNAME}/django-backend:latest
${DOCKER_USERNAME}/django-frontend:latest
```

This ensures images are pushed to Docker Hub during CI.

---

## AWS EC2 Deployment (Automatic)

An EC2 instance (Ubuntu) was launched with:

- Port 22 (SSH)
- Port 8000 (Backend)
- Port 3000 (Frontend)

Docker and Docker Compose were installed on EC2.

### GitHub Secrets for Deployment

- `EC2_HOST`
- `EC2_USER`
- `SSH_PRIVATE_KEY`

---

## SSH Deployment Automation

Deployment is handled using:

```
appleboy/ssh-action
```

### Deployment Script

```yaml
script: |
  export DOCKER_USERNAME=${{ secrets.DOCKER_USERNAME }}

  if [ ! -d "django-docker-ci-cd-pipeline" ]; then
    git clone https://github.com/Agnus-sk/django-docker-ci-cd-pipeline.git
  fi

  cd django-docker-ci-cd-pipeline
  git pull
  docker compose pull
  docker compose up -d
```

### Deployment Flow

1. CI builds images
2. Images pushed to Docker Hub
3. GitHub connects to EC2 via SSH
4. EC2 pulls latest images
5. Containers restart automatically

No manual deployment required.

---

## Handling Environment Variables

To avoid hardcoding IP addresses:

In `settings.py`:

```python
import os

ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "*").split(",")
```

In `docker-compose.yml`:

```yaml
environment:
  - ALLOWED_HOSTS=*
```

This ensures:

- No IP dependency
- No need to update code if EC2 IP changes
- Production-ready configuration practice

---

## Final Working Architecture

CI/CD Pipeline Flow:

Developer Push → GitHub Actions →  
Build Images → Push to Docker Hub →  
SSH into EC2 → Pull Images → Restart Containers

Services Running:

- Backend: http://EC2_PUBLIC_IP:8000
- Frontend: http://EC2_PUBLIC_IP:3000

Containers Verified Using:

```bash
docker ps
```

---

## Key DevOps Concepts Implemented

- Multi-service containerization
- Docker Compose orchestration
- CI/CD automation with GitHub Actions
- Secure secret management
- Docker Hub image registry
- Remote deployment via SSH
- Environment-based configuration
- Infrastructure recreation capability

---

## Result

A fully automated CI/CD pipeline capable of:

- Building Docker images
- Pushing images to Docker Hub
- Deploying to AWS EC2 automatically
- Restarting services on every push

No manual intervention required after code push.

---

