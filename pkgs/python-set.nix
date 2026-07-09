# Returns a python3 whose package set has the Gramps Web packages added
# (gramps + gramps-ql + object-ql + sifts + gramps-web-api). Self-contained: it
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

  grampsOverrides = pyfinal: _pyprev: {
    gramps         = noCheck (pyfinal.callPackage ./gramps { });
    gramps-ql      = noCheck (pyfinal.callPackage ./gramps-ql.nix { });
    object-ql      = noCheck (pyfinal.callPackage ./object-ql.nix { });
    sifts          = noCheck (pyfinal.callPackage ./sifts.nix { });
    gramps-web-api = noCheck (pyfinal.callPackage ./gramps-web-api { });
  };
in
pkgs.python3.override (old: {
  packageOverrides = pkgs.lib.composeExtensions
    (old.packageOverrides or (_: _: { }))
    grampsOverrides;
})
