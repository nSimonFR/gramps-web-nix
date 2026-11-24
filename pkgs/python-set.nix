# Returns a python3 whose package set has the Gramps Web packages added
# (gramps + gramps-ql + gramps-object-query-language + gramps-web-api and the
# deps nixpkgs lacks). Self-contained: it
# does NOT mutate the caller's global `python3Packages`, so a host can import the
# module without every other python package on the system rebuilding.
#
# Reused by both flake.nix (package outputs) and module.nix (the gunicorn/celery
# runtime env).
#
# These derivations are carried from nixpkgs draft PR #417806 (TomaSajt:
# "gramps-web: init at 25.6.0; python3Packages.gramps-web-api: init at 3.2.0")
# and built against the caller's nixpkgs. Deviations from upstream:
#   - gramps-web-api drops the AI extras (accelerate/openai/sentence-transformers
#     → PyTorch): far too heavy for a small self-host, and unused without the
#     semantic-search/chat features.
#   - doCheck disabled: the upstream suites are slow and occasionally
#     network/model-dependent (painful on aarch64 / low-memory hosts).
#     pythonImportsCheck still runs as a smoke test.
pkgs:
let
  noCheck = pkg: pkg.overridePythonAttrs (_: {
    doCheck = false;
    doInstallCheck = false;
  });

  grampsOverrides = pyfinal: pyprev: {
    gramps         = noCheck (pyfinal.callPackage ./gramps { });
    gramps-ql      = noCheck (pyfinal.callPackage ./gramps-ql.nix { });
    gramps-object-query-language =
      noCheck (pyfinal.callPackage ./gramps-object-query-language.nix { });
    gramps-gedcom7 = noCheck (pyfinal.callPackage ./gramps-gedcom7.nix { });
    gedcom7        = noCheck (pyfinal.callPackage ./gedcom7.nix { });
    yclade         = noCheck (pyfinal.callPackage ./yclade.nix { });
    flask-smorest  = noCheck (pyfinal.callPackage ./flask-smorest.nix { });
    # gramps-web-api >= 3.25 requires Authlib >= 1.9 (OIDC); some nixpkgs
    # revisions still ship 1.7.
    authlib =
      if pkgs.lib.versionAtLeast pyprev.authlib.version "1.9.0" then pyprev.authlib
      else noCheck (pyprev.authlib.overridePythonAttrs (_: rec {
        version = "1.9.10";
        src = pkgs.fetchPypi {
          pname = "authlib";
          inherit version;
          hash = "sha256-90U8Sj9ZdflMxVIjxNSP+cfY07Tj1yftJUntrrm4XVA=";
        };
      }));
    gramps-web-api = noCheck (pyfinal.callPackage ./gramps-web-api { });
  };
in
pkgs.python3.override (old: {
  packageOverrides = pkgs.lib.composeExtensions
    (old.packageOverrides or (_: _: { }))
    grampsOverrides;
})
