{
  description = "flix-miniparse: educational PEG/parsec library for Flix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              flix
              # Flix requires Java 21+. The flix wrapper already bundles a JRE,
              # but an explicit JDK is handy for tooling and diagnostics.
              jdk21
            ];

            shellHook = ''
              echo "Flix development shell"
              echo "  flix: $(flix --version 2>/dev/null || echo unknown)"
              echo "  java: $(java -version 2>&1 | head -1)"
              echo ""
              echo "Common commands:"
              echo "  flix init   # scaffold a new project"
              echo "  flix run    # compile and run"
              echo "  flix test   # run tests"
              echo "  flix build  # build artifacts"
            '';
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
