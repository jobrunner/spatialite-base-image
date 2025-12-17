{
  description = "Development environment for spatialite-base-image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "spatialite-dev";

          buildInputs = with pkgs; [
            # Dockerfile linting and security
            hadolint
            trivy

            # Docker tools
            docker
            docker-buildx
          ];

          shellHook = ''
            echo "spatialite-base-image dev environment"
            echo ""
            echo "Available tools:"
            echo "  hadolint  - Dockerfile linter"
            echo "  trivy     - Security scanner"
            echo "  docker    - Container runtime"
            echo ""
          '';
        };
      }
    );
}
