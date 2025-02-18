{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default";
    zig = {
      url = "github:ziglang/zig";
      flake = false;
    };
    zls = {
      url = "github:zigtools/zls";
      flake = false;
    };
    zon2nix = {
      url = "github:MidstallSoftware/zon2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      zon2nix,
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
                version = "0.14.0-git+${inputs.zig.shortRev or "dirty"}";
                src = inputs.zig;

                doInstallCheck = false;

                postBuild = "";
                postInstall = "";

                cmakeFlags = [
                  "-DZIG_VERSION=0.14.0-dev.3239+d7b93c787"
                ];

                outputs = [ "out" ];
              }
            )).override
              {
                llvmPackages = llvmPackages_19;
              };

          zon2nix = stdenv.mkDerivation {
            pname = "zon2nix";
            version = "0.1.2";

            src = lib.cleanSource inputs.zon2nix;

            nativeBuildInputs = [
              pkgs.zig
              pkgs.zig.hook
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
            version = "0.14.0-git+${inputs.zls.shortRev or "dirty"}";
            src = lib.cleanSource inputs.zls;

            nativeBuildInputs = [
              pkgs.zig
              pkgs.zig.hook
            ];
          };
        };
    in
    {
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
            ];
          };
        }
      );
    };
}
