{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  setuptools-scm,
  networkx,
  platformdirs,
}:

buildPythonPackage rec {
  pname = "yclade";
  version = "0.7.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-XBd9VrXu1PSeMXnZRk6KSUubtzC2X91ecAPsGtgXbZs=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    networkx
    platformdirs
  ];

  pythonImportsCheck = [ "yclade" ];

  meta = {
    description = "Find a Y-DNA clade from a set of SNPs";
    homepage = "https://github.com/DavidMStraub/yclade";
    license = lib.licenses.mit;
  };
}
