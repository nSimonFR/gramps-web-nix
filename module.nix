# NixOS module for Gramps Web — self-hosted genealogy (gramps-web + gramps-web-api).
#
# Usage in nic-os (or any NixOS flake):
#
#   inputs.gramps-web-nix.url = "github:nSimonFR/gramps-web-nix";
#
#   imports = [ inputs.gramps-web-nix.nixosModules.gramps-web ];
#   services.gramps-web = {
#     enable        = true;
#     baseUrl       = "https://gramps.example.ts.net";
#     redisUrl      = "redis://127.0.0.1:6379/6";   # Celery broker/result backend
#     secretKeyFile = "/run/agenix/gramps-web-secret";
#   };
#
# Redis and (optionally) a reverse proxy are provided by the host. This module
# ships a plain, always-on service. To make it sleep when idle on a
# memory-constrained host, wrap gramps-web.service with a socket-activation proxy
# host-side (the module keeps host/port configurable and changes nothing else) —
# gramps-web-celery is the companion worker to bind to that lifecycle.
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.gramps-web;

  frontend = pkgs.callPackage (self + "/pkgs/frontend.nix") { };

  # Self-contained python3 with gramps-web-api + its Gramps deps (see
  # pkgs/python-set.nix — does not touch the host's global python3Packages),
  # plus gunicorn (WSGI server) and celery (its console script).
  pythonEnv = (import (self + "/pkgs/python-set.nix") pkgs).withPackages (ps: [
    ps.gramps-web-api
    ps.gunicorn
    ps.celery
  ]);

  # GObject-Introspection typelibs Gramps loads via gi.require_version() at
  # import. gramps-web-api is built with wrapGAppsHook3, but we launch it via
  # gunicorn (not its wrapped entry point), so GI_TYPELIB_PATH must be set here.
  # pango/glib default to their -bin output (no typelibs) → use .out.
  typelibPkgs = with pkgs; [
    gobject-introspection at-spi2-core gtk3
    glib.out pango.out gdk-pixbuf gexiv2 osm-gps-map harfbuzz
  ];
  giTypelibPath = lib.concatMapStringsSep ":" (p: "${p}/lib/girepository-1.0") typelibPkgs;

  # Tools Celery shells out to (thumbnails, OCR, report/media export).
  runtimePkgs = with pkgs; [ ffmpeg-headless tesseract poppler-utils graphviz ghostscript ];

  commonEnv = {
    GRAMPSWEB_TREE = cfg.tree;
    GRAMPSWEB_BASE_URL = cfg.baseUrl;
    GRAMPSWEB_USER_DB_URI = "sqlite:///${cfg.dataDir}/data/users.sqlite";
    GRAMPSWEB_SEARCH_INDEX_DB_URI = "sqlite:///${cfg.dataDir}/indexdir/search_index.db";
    GRAMPSWEB_MEDIA_BASE_DIR = "${cfg.dataDir}/media";
    GRAMPSWEB_STATIC_PATH = "${cfg.package}/share/gramps-web/static";
    GRAMPSWEB_THUMBNAIL_CACHE_CONFIG__CACHE_DIR = "${cfg.dataDir}/cache/thumbnails";
    GRAMPSWEB_REQUEST_CACHE_CONFIG__CACHE_DIR = "${cfg.dataDir}/cache/request_cache";
    GRAMPSWEB_PERSISTENT_CACHE_CONFIG__CACHE_DIR = "${cfg.dataDir}/cache/persistent_cache";
    GRAMPSWEB_REPORT_DIR = "${cfg.dataDir}/cache/reports";
    GRAMPSWEB_EXPORT_DIR = "${cfg.dataDir}/cache/export";
    GRAMPS_DATABASE_PATH = "${cfg.dataDir}/data/grampsdb";
    GRAMPSHOME = cfg.dataDir;
    CELERY_BROKER_URL = cfg.redisUrl;
    CELERY_RESULT_BACKEND = cfg.redisUrl;
    GI_TYPELIB_PATH = giTypelibPath;
    TMPDIR = "${cfg.dataDir}/tmp";
    OMP_NUM_THREADS = "1";  # limit thread fan-out on small hosts
  } // cfg.settings;

  # Export the Flask session secret (from a file, kept out of the store) before
  # exec'ing the given command.
  withSecret = cmd: ''
    ${lib.optionalString (cfg.secretKeyFile != null) ''
      export GRAMPSWEB_SECRET_KEY="$(cat ${cfg.secretKeyFile})"
    ''}
    ${cmd}
  '';

  commonServiceConfig = {
    User = cfg.user;
    Group = cfg.group;
    WorkingDirectory = cfg.dataDir;
    Restart = "on-failure";
    RestartSec = "5s";
    # Many small hosts (e.g. RPi5) have no user namespaces; nixpkgs' default
    # PrivateUsers=true fails there. Off by default; harden host-side if wanted.
    PrivateUsers = lib.mkForce false;
  };
in
{
  options.services.gramps-web = {
    enable = lib.mkEnableOption "Gramps Web self-hosted genealogy";

    package = lib.mkOption {
      type = lib.types.package;
      default = frontend;
      defaultText = lib.literalExpression "gramps-web (the grampsjs frontend)";
      description = "The grampsjs frontend derivation (serves .../share/gramps-web/static).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address gunicorn binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port gunicorn (the API + SPA) listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/gramps-web";
      description = "Directory for persistent state (Gramps DB, media, search index, caches).";
    };

    user = lib.mkOption { type = lib.types.str; default = "gramps-web"; };
    group = lib.mkOption { type = lib.types.str; default = "gramps-web"; };

    tree = lib.mkOption {
      type = lib.types.str;
      default = "Family Tree";
      description = "GRAMPSWEB_TREE — name of the family tree.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://gramps.example.ts.net";
      description = "Public URL the app is served from → GRAMPSWEB_BASE_URL (absolute links).";
    };

    redisUrl = lib.mkOption {
      type = lib.types.str;
      default = "redis://127.0.0.1:6379/0";
      description = "Redis URL for the Celery broker + result backend.";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/gramps-web-secret";
      description = ''
        Path to a file containing the Flask session secret (GRAMPSWEB_SECRET_KEY).
        Read at start so it stays out of the world-readable Nix store.
      '';
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "384M";
      description = "systemd MemoryMax= for the gunicorn (web) service.";
    };

    celeryMemoryMax = lib.mkOption {
      type = lib.types.str;
      default = "256M";
      description = "systemd MemoryMax= for the Celery worker.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { GRAMPSWEB_EMAIL_HOST = "smtp.example.com"; };
      description = "Extra GRAMPSWEB_* / environment variables merged into both services.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = lib.mkIf (cfg.user == "gramps-web") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = false;
    };
    users.groups.${cfg.group} = lib.mkIf (cfg.group == "gramps-web") { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}                    0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data               0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data/grampsdb      0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/media              0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/indexdir           0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/cache              0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/cache/thumbnails         0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/cache/request_cache      0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/cache/persistent_cache   0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/cache/reports      0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/cache/export       0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/tmp                0750 ${cfg.user} ${cfg.group} -"
    ];

    # ── gramps-web: gunicorn (API + SPA) ─────────────────────────────────────
    systemd.services.gramps-web = {
      description = "Gramps Web";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.coreutils ] ++ runtimePkgs;
      environment = commonEnv;
      script = withSecret ''
        # Idempotent user-DB migration.
        ${pythonEnv}/bin/python3 -m gramps_webapi user migrate || true
        exec "${pythonEnv}/bin/gunicorn" \
          -w 1 \
          -b ${cfg.host}:${toString cfg.port} \
          --timeout 120 \
          --limit-request-line 8190 \
          gramps_webapi.wsgi:app
      '';
      serviceConfig = commonServiceConfig // {
        Type = "simple";
        MemoryMax = cfg.memoryMax;
      };
    };

    # ── gramps-web-celery: background worker (thumbnails, indexing, exports) ──
    systemd.services.gramps-web-celery = {
      description = "Gramps Web Celery Worker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.coreutils ] ++ runtimePkgs;
      environment = commonEnv;
      script = withSecret ''
        exec "${pythonEnv}/bin/celery" \
          -A gramps_webapi.celery \
          worker \
          --loglevel=info \
          --concurrency=1
      '';
      serviceConfig = commonServiceConfig // {
        Type = "simple";
        RestartSec = "10s";
        MemoryMax = cfg.celeryMemoryMax;
      };
    };
  };
}
