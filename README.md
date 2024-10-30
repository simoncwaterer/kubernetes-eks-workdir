```
# Web Application Project

This project is part of a LinkedIn course introducing Kubernetes. The course uses a web application as a sample project, demonstrating the transition from Docker to Kubernetes on AWS EKS.

## Project Overview

The web application consists of a static website with sliding menus for desktop users. The project is designed to be deployed on AWS EKS, leveraging Kubernetes for container orchestration.

## Deployment

The project is intended to be deployed on AWS EKS, utilizing Kubernetes for managing containerized applications. The transition from Docker to Kubernetes involves creating Kubernetes manifests for deployment, services, and other necessary resources.

## Prerequisites

- **Docker**: Ensure Docker is installed for building container images.
- **Kubernetes**: Familiarity with Kubernetes concepts and tools like `kubectl`.
- **AWS CLI**: Set up AWS CLI for interacting with AWS services.
- **AWS EKS**: An EKS cluster should be available for deploying the application.

## Getting Started

1. **Build Docker Image**: Create a Docker image of the web application.
   ```bash
   docker build -t your-image-name .
   ```

2. **Push to Container Registry**: Push the Docker image to a container registry accessible by your EKS cluster.

3. **Deploy to EKS**: Use Kubernetes manifests to deploy the application to your EKS cluster.
   ```bash
   kubectl apply -f deployment.yaml
   ```

4. **Access the Application**: Once deployed, access the application through the service endpoint provided by Kubernetes.

## Conclusion

This project serves as a practical introduction to deploying web applications on Kubernetes, specifically on AWS EKS. By following the course, you will gain hands-on experience in container orchestration and cloud deployment strategies.
```