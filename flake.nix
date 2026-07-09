{
  description = "Nix packaging for Gramps Web — self-hosted genealogy (gramps-project/gramps-web + gramps-web-api)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem = { pkgs, ... }:
        let
          pythonSet = import ./pkgs/python-set.nix pkgs;
        in
        {
          packages.gramps-web     = pkgs.callPackage ./pkgs/frontend.nix { };
          packages.gramps-web-api = pythonSet.pkgs.gramps-web-api;
          packages.default        = self.packages.${pkgs.system}.gramps-web;
        };

      flake = {
        nixosModules.gramps-web = import ./module.nix self;
        nixosModules.default    = self.nixosModules.gramps-web;

        # Convenience overlay: adds `pkgs.gramps-web` (frontend) and the Gramps
        # Web python packages. Not used by the module (which keeps its python set
        # self-contained via pkgs/python-set.nix), but handy for consumers.
        overlays.default = final: prev:
          let pythonSet = import ./pkgs/python-set.nix final; in
          {
            gramps-web = final.callPackage ./pkgs/frontend.nix { };
            python3 = pythonSet;
            python3Packages = pythonSet.pkgs;
          };
      };
    };
}
