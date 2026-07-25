{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig = {
      url = "git+https://codeberg.org/ziglang/zig?shallow=1";
      flake = false;
    };
    zls = {
      url = "github:zigtools/zls/0.16.0";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      eachSystem = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
        "riscv64-linux"
      ];

      defaultOverlay =
        pkgs: prev: with pkgs; {
          zig =
            (prev.zig.overrideAttrs (
              finalAttrs: p: {
                version = "0.17.0-git+${inputs.zig.shortRev or "dirty"}";
                src = inputs.zig;

                doInstallCheck = false;

                postBuild = "";
                postInstall = "";

                cmakeFlags = [
                  "-DZIG_VERSION=0.17.0-dev.9999+${inputs.zig.shortRev or "dirty"}"
                ];

                nativeBuildInputs = [
                  cmake
                  ninja
                  stdenv.cc.cc.lib
                  llvmPackages_22.lld
                  llvmPackages_22.llvm
                ]
                ++ lib.optionals (!stdenv.isDarwin) [ autoPatchelfHook ];

                outputs = [ "out" ];
              }
            )).override
              {
                llvmPackages = llvmPackages_22;
              };

          zls = stdenv.mkDerivation (finalAttrs: {
            pname = "zls";
            version = "0.16.0-git+${inputs.zls.shortRev or "dirty"}";
            src = lib.cleanSource inputs.zls;

            postConfigure = ''
              ln -s ${
                prev.zig.fetchDeps {
                  inherit (finalAttrs)
                    src
                    pname
                    version
                    ;
                  hash = "sha256-I9mWQL83hYDOyL6sTEWgzzYyV8w0v6kmbTmUV7HO6K0=";
                }
              } $ZIG_GLOBAL_CACHE_DIR/p
            '';

            nativeBuildInputs = [
              prev.zig
            ];
          });

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
          inherit (pkgs) zig zls zlinter;
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
            ];
          };
        }
      );
    };
}
