{
  description = "A faster, persistent implementation of `direnv`'s `use_nix`, to replace the built-in one.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      {
        imports = [ ./treefmt.nix ];
        systems = [
          "aarch64-linux"
          "x86_64-linux"

          "x86_64-darwin"
          "aarch64-darwin"
        ];
        perSystem =
          {
            config,
            pkgs,
            self',
            ...
          }:
          let
            nix-direnv = pkgs.callPackage ./default.nix { };
            test_pkgs = pkgs.lib.callPackagesWith pkgs ./tests { inherit nix-direnv; };
            mkBashOverlay =
              functions:
              pkgs.runCommand "bash_overlay"
                {
                  # TODO: does this have to be native?
                  nativeBuildInputs = [ pkgs.gawk ];
                }
                # TODO: uncurse the vibe-coded impl, is this really the best way?
                ''
                  mkdir -p "$out"
                  awk -v functions=${lib.escapeShellArg (lib.concatStringsSep " " functions)} '
                    BEGIN {
                      count = split(functions, names, " ")
                      for (i = 1; i <= count; i++) wanted[names[i]] = 1
                    }
                    /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/ {
                      name = $0
                      sub(/[[:space:]]*\(\).*/, "", name)
                      printing = (name in wanted)
                      if (printing) {
                        found[name] = 1
                        if (printed++) print ""
                      }
                    }
                    printing { print }
                    END {
                      for (i = 1; i <= count; i++) {
                        if (!(names[i] in found)) {
                          printf "bash_overlay: function not found in direnvrc: %s\n", names[i] > "/dev/stderr"
                          failed = 1
                        }
                      }
                      exit failed
                    }
                  ' ${./direnvrc} > "$out/nix-direnv-multislot-overlay.sh"
                '';
          in
          {
            packages = test_pkgs // {
              inherit nix-direnv;
              default = nix-direnv;
              bash_overlay =
                let
                  fns_modified_vs_upstream = [ "use_flake" ];
                in
                  mkBashOverlay fns_modified_vs_upstream;
            };

            devShells.default = pkgs.callPackage ./shell.nix {
              treefmt = config.treefmt.build.wrapper;
            };

            checks =
              let
                packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
                devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
              in
              packages // devShells;
          };
        flake = {
          overlays.default = final: _prev: { nix-direnv = final.callPackage ./default.nix { }; };
          templates.default = {
            path = ./templates/flake;
            description = "nix flake new -t github:nix-community/nix-direnv .";
          };
        };
      }
    );
}
