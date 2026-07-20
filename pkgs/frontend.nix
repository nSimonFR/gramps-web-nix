{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "gramps-web";
  version = "26.6.2";

  src = fetchFromGitHub {
    owner = "gramps-project";
    repo = "gramps-web";
    tag = "v${finalAttrs.version}";
    hash = "sha256-hoEYV7sXHqibxmFJptbHgVTDppM2+Q7njA75UJClKlQ=";
  };

  npmDepsHash = "sha256-cV5wM0xIRnNBiF94J+93S0El5oVT6TMoe3sntVHbkKM=";

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
