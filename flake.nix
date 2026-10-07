{
  description = "lc and Lightcone Lab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    lightcone = {
      url = "github:charnock-fr/lightcone-cli/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lab = {
      url = "github:LightconeResearch/jupyterlab-lightcone";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      lightcone,
      lab,
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      excludeNewer =
        let
          date = lib.max lab.lastModifiedDate lightcone.lastModifiedDate;
          at = start: length: builtins.substring start length date;
        in
        "${at 0 4}-${at 4 2}-${at 6 2}T${at 8 2}:${at 10 2}:${at 12 2}Z";
      kernelsFor =
        pkgs:
        pkgs.writeTextDir "share/jupyter/kernels/uv-project/kernel.json" (
          builtins.toJSON {
            argv = [
              "uv"
              "run"
              "--managed-python"
              "--locked"
              "--with"
              "ipykernel"
              "python"
              "-m"
              "ipykernel_launcher"
              "-f"
              "{connection_file}"
            ];
            display_name = "Python (project)";
            language = "python";
          }
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lc = lightcone.packages.${system}.default;
          lightcone-lab = pkgs.writeShellApplication {
            name = "lightcone-lab";
            runtimeInputs = [
              lc
              pkgs.coreutils
              pkgs.nodejs
            ];
            text = ''
              src=${lab}
              wheels=''${XDG_CACHE_HOME:-$HOME/.cache}/lightcone-dev/lab/''${src#/nix/store/}
              if [ ! -d "$wheels" ]; then
                mkdir -p "''${wheels%/*}"
                build=$(mktemp -d "$wheels.XXXXXX")
                trap 'rm -rf "$build"' EXIT
                cp -r --no-preserve=mode "$src" "$build/src"
                uv build --quiet --managed-python --exclude-newer ${excludeNewer} \
                  --wheel --out-dir "$build/dist" "$build/src"
                mv "$build/dist" "$wheels"
                rm -rf "$build"
              fi
              lab_wheel=$(echo "$wheels"/*.whl)
              lc_wheel=$(echo ${lc.dist}/*.whl)
              export JUPYTER_PATH=${kernelsFor pkgs}/share/jupyter''${JUPYTER_PATH:+:$JUPYTER_PATH}
              exec uv tool run --quiet --managed-python --exclude-newer ${excludeNewer} \
                --from "jupyterlab-lightcone[dev] @ file://$lab_wheel" --with "$lc_wheel" \
                jupyter lab "$@"
            '';
          };
        in
        {
          inherit lightcone-lab;
          default = lightcone-lab;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          unfree = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
          };
          default = pkgs.mkShell {
            packages = [
              lightcone.packages.${system}.default
              self.packages.${system}.lightcone-lab
              pkgs.nodejs
            ];
            JUPYTER_PATH = "${kernelsFor pkgs}/share/jupyter";
          };
        in
        {
          inherit default;
          claude = default.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [
              unfree.claude-code
              unfree.claude-agent-acp
            ];
          });
        }
      );
    };
}
