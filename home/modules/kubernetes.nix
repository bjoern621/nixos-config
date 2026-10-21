{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kubectl
    kubelogin-oidc # kubectl oidc-login, the Keycloak login of the hh cluster
    k9s
  ];

  # The hh cluster's API server on its tailnet address, signed in through Keycloak realm main.
  # The CA certificate holds no secret.
  home.file.".kube/hh.yaml".text = ''
    apiVersion: v1
    kind: Config
    clusters:
      - name: hh
        cluster:
          server: https://100.79.197.78:6443
          certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJlRENDQVIyZ0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQWpNU0V3SHdZRFZRUUREQmhyTTNNdGMyVnkKZG1WeUxXTmhRREUzTnpVNU9UWTVPVFV3SGhjTk1qWXdOREV5TVRJeU9UVTFXaGNOTXpZd05EQTVNVEl5T1RVMQpXakFqTVNFd0h3WURWUVFEREJock0zTXRjMlZ5ZG1WeUxXTmhRREUzTnpVNU9UWTVPVFV3V1RBVEJnY3Foa2pPClBRSUJCZ2dxaGtqT1BRTUJCd05DQUFRR2VTck1DbXNCeUt6b2ZESUp0VjhsbXQ0T0tQWmFZcXZrZFlkT1hvWnIKWDVlWjZvcmFDbHZyUWloOEd3OTY0aVB5L2FlblhnS3U1R1pmeXU1UVBSNkFvMEl3UURBT0JnTlZIUThCQWY4RQpCQU1DQXFRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVXUvNXBjRzlSaXI2KzdLUC96Y2NXCmRidEVDUVF3Q2dZSUtvWkl6ajBFQXdJRFNRQXdSZ0loQU5DK1BMektVVmRLOTgyK3BRa3FYTUY2bTdkaCs3NHIKakFGUlhpejZhcTVaQWlFQTJzVFpQSXpZTThVNzN4clMraWp0bXVURDlZN01qZDhUL3dBOWpWVWYySDA9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    users:
      - name: hh-keycloak
        user:
          exec:
            apiVersion: client.authentication.k8s.io/v1
            command: kubectl
            args:
              - oidc-login
              - get-token
              - --oidc-issuer-url=https://identity.bjoernblessin.de/realms/main
              - --oidc-client-id=kubernetes
              - --oidc-extra-scope=profile
            interactiveMode: IfAvailable
    contexts:
      - name: hh
        context:
          cluster: hh
          user: hh-keycloak
    current-context: hh
  '';

  # ~/.kube/config comes first: kubectl and k9s write the chosen context into the first file,
  # and the generated one is read-only.
  # It holds the k3s admin certificate, kept for the case that Keycloak itself is down.
  home.sessionVariables.KUBECONFIG = "$HOME/.kube/config:$HOME/.kube/hh.yaml";
}
