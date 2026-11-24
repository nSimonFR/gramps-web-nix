{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  setuptools-scm,
  click,
  gedcom7,
  gramps,
}:

buildPythonPackage rec {
  pname = "gramps-gedcom7";
  version = "0.6.0";
  pyproject = true;

  src = fetchPypi {
    pname = "gramps_gedcom7";
    inherit version;
    hash = "sha256-QCrl/hRTGYkqpAF54y/JUVR3ZWBAUSFVWCaGvfLSUes=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    click
    gedcom7
    gramps
  ];

  pythonImportsCheck = [ "gramps_gedcom7" ];

  meta = {
    description = "GEDCOM 7 import for Gramps";
    homepage = "https://github.com/DavidMStraub/gramps-gedcom7";
    license = lib.licenses.agpl3Only;
  };
}
