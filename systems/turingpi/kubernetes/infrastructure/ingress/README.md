# Centralized Ingress Management

This directory contains all ingress-related configurations for the Turing Pi cluster.

## Structure

```
ingress/
├── controllers/          # Ingress controllers (nginx, traefik, etc.)
│   └── nginx/           # Current nginx-ingress controller
├── rules/               # Ingress rules for different services
│   ├── lgtm/            # LGTM stack ingress rules
│   └── longhorn/        # Longhorn dashboard ingress rules
└── kustomization.yaml   # Main ingress kustomization
```

## Benefits of This Structure

1. **Centralized Management**: All ingress configurations in one place
2. **Easy Controller Switching**: Change from nginx to traefik without touching apps
3. **Better Organization**: Clear separation of concerns
4. **Reusability**: Ingress rules can be shared across stacks

## Current Controller: nginx-ingress

- **Version**: 4.7.1
- **Type**: LoadBalancer
- **Node Selector**: Worker nodes only
- **Security**: Non-root, read-only filesystem

## Adding New Services

To add ingress for a new service:

1. Create a new rule file in `rules/`
2. Add it to the main `kustomization.yaml`
3. Apply with Flux

## Future: Traefik Migration

Planning to migrate from nginx to Traefik for:
- Better Kubernetes integration
- Built-in Let's Encrypt support
- More modern features