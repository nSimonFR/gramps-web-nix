{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  setuptools-scm,
}:

buildPythonPackage rec {
  pname = "gedcom7";
  version = "1.4.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-no6Ze7vHiUJgJchqITqda6lb0qB7ojKaoILIV5Vj+HI=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  pythonImportsCheck = [ "gedcom7" ];

  meta = {
    description = "GEDCOM 7 parser";
    homepage = "https://github.com/DavidMStraub/python-gedcom7";
    license = lib.licenses.mit;
  };
}
