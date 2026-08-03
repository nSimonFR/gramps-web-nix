{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "gramps-web";
  version = "26.7.1";

  src = fetchFromGitHub {
    owner = "gramps-project";
    repo = "gramps-web";
    tag = "v${finalAttrs.version}";
    hash = "sha256-H7mEhGvWrhLVKcSE9PqY6Q2yAlVSu2e2B5YwwaAEHPg=";
  };

  npmDepsHash = "sha256-4+2Il75jlU1Dtg9goQ2hevg6Bkk1WgPuDi3FwQ3WafE=";

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
