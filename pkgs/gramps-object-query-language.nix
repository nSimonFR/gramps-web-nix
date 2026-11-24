{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  gramps,
}:

buildPythonPackage rec {
  pname = "gramps-object-query-language";
  version = "0.5.19";
  pyproject = true;

  src = fetchPypi {
    pname = "gramps_object_query_language";
    inherit version;
    hash = "sha256-H2KTttbDetpwtTPdfXPgv/mpYb/fGFlVHSqSWTwUxjE=";
  };

  build-system = [ setuptools ];

  dependencies = [ gramps ];

  pythonImportsCheck = [ "gramps_object_query_language" ];

  meta = {
    description = "Object query language for Gramps data";
    homepage = "https://github.com/dsblank/gramps-object-query-language";
    license = lib.licenses.agpl3Plus;
  };
}
