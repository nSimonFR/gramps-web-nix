{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "gramps-web";
  version = "25.12.0";

  src = fetchFromGitHub {
    owner = "gramps-project";
    repo = "gramps-web";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0uk0xWW/yz41Lummf/rvYyNyGGEexBfwb0wbWS7ogtQ=";
  };

  npmDepsHash = "sha256-HM/ekV8cBEV+9V5f2bjPQuEDQOB025iLYBHNcUyfx6w=";

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
