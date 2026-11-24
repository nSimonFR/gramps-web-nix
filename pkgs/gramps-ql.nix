{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  setuptools-scm,
  gramps,
  pyparsing,
}:

buildPythonPackage rec {
  pname = "gramps-ql";
  version = "0.5.0";
  pyproject = true;

  src = fetchPypi {
    pname = "gramps_ql";
    inherit version;
    hash = "sha256-jaAIj477T/+Zw0VzlR7OUwdAccGbMSckIcabIMs+q8A=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    gramps
    pyparsing
  ];

  pythonImportsCheck = [ "gramps_ql" ];

  meta = {
    description = "Library to filter Gramps database objects by a query syntax";
    homepage = "https://github.com/DavidMStraub/gramps-ql";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ tomasajt ];
  };
}
