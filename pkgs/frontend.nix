{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "gramps-web";
  version = "25.6.0";

  src = fetchFromGitHub {
    owner = "gramps-project";
    repo = "gramps-web";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rcgvog9OPIuP0QyWDh8vqkpF/upUtB7FthCHLzG64C0=";
  };

  # CARTO's keyless raster tiles now answer "API KEY REQUIRED". Switch to the
  # OSM standard layer; releases >= 25.9.0 moved to OpenFreeMap upstream.
  postPatch = ''
    substituteInPlace src/components/GrampsjsMap.js \
      --replace-fail "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png" \
                     "https://tile.openstreetmap.org/{z}/{x}/{y}.png" \
      --replace-fail "; <a href=\"https://carto.com/attributions\">CARTO</a>" ""
  '';

  npmDepsHash = "sha256-05s6JbH6hCqLNtOKAx4E56xEuHTGdT/957d6Gg4MiKk=";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/gramps-web/
    cp -r dist $out/share/gramps-web/static

    runHook postInstall
  '';

  meta = {
    description = "Frontend for Gramps Web";
    homepage = "https://github.com/gramps-project/gramps-web";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ tomasajt ];
    platforms = lib.platforms.all;
  };
})
