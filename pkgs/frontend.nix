{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "gramps-web";
  version = "26.9.1";

  src = fetchFromGitHub {
    owner = "gramps-project";
    repo = "gramps-web";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ej2uTYfdw0as31Xg5yXwpHl8OVJAzVFnTTnA/q3I4Nk=";
  };

  npmDepsHash = "sha256-Wm4+0GihvvcBXs1oaaBzmKrS5/sqCUeoBrU9LlUDMgU=";

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
