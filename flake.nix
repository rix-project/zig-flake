{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default";
    zig = {
      url = "github:ziglang/zig";
      flake = false;
    };
    zon2nix = {
      url = "github:nix-community/zon2nix";
      flake = false;
    };
    zls = {
      url = "github:zigtools/zls";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      eachSystem = nixpkgs.lib.genAttrs (import systems);

      defaultOverlay =
        pkgs: prev: with pkgs; {
          zig =
            (prev.zig.overrideAttrs (
              finalAttrs: p: {
                version = "0.15.0-git+${inputs.zig.shortRev or "dirty"}";
                src = inputs.zig;

                doInstallCheck = false;

                postBuild = "";
                postInstall = "";

                cmakeFlags = [
                  "-DZIG_VERSION=0.15.0-dev.9999+${inputs.zig.shortRev or "dirty"}"
                ];

                nativeBuildInputs = [
                  cmake
                  ninja
                  stdenv.cc.cc.lib
                  llvmPackages_20.lld
                  llvmPackages_20.llvm
                ] ++ lib.optionals (!stdenv.isDarwin) [ autoPatchelfHook ];

                outputs = [ "out" ];
              }
            )).override
              {
                llvmPackages = llvmPackages_20;
              };

          zon2nix = stdenv.mkDerivation {
            pname = "zon2nix";
            version = "0.1.2";

            src = inputs.zon2nix;

            nativeBuildInputs = [
              zig
              zig.hook
            ];

            zigBuildFlags = [
              "-Dnix=${lib.getExe nix}"
            ];

            zigCheckFlags = [
              "-Dnix=${lib.getExe nix}"
            ];
          };

          zls = stdenv.mkDerivation {
            pname = "zls";
            version = "0.15.0-git+${inputs.zls.shortRev or "dirty"}";
            src = lib.cleanSource inputs.zls;

            postPatch = ''
              ln -s ${callPackage ./zls.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
            '';

            nativeBuildInputs = [
              zig
              zig.hook
            ];
          };
        };
    in
    {
      overlays.default = defaultOverlay;

      packages = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
            defaultOverlay
          ];
        in
        {
          default = pkgs.zig;
          zig = pkgs.zig;
          zls = pkgs.zls;
          zon2nix = pkgs.zon2nix;
        }
      );

      devShells = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
            defaultOverlay
          ];
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              pkgs.zig
              pkgs.zls
              pkgs.zon2nix
            ];
          };
        }
      );
    };
}
