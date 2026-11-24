{
  lib,
  buildPythonPackage,
  fetchPypi,
  flit-core,
  apispec,
  flask,
  marshmallow,
  webargs,
  werkzeug,
}:

buildPythonPackage rec {
  pname = "flask-smorest";
  version = "0.47.0";
  pyproject = true;

  src = fetchPypi {
    pname = "flask_smorest";
    inherit version;
    hash = "sha256-pBXOfbPX5j3YVOsW1ZBHaG2/XTHEkT4kX6Vlf4jneI0=";
  };

  build-system = [ flit-core ];

  dependencies = [
    apispec
    flask
    marshmallow
    webargs
    werkzeug
  ]
  ++ apispec.optional-dependencies.marshmallow;

  pythonImportsCheck = [ "flask_smorest" ];

  meta = {
    description = "DB agnostic framework to build auto-documented REST APIs with Flask and marshmallow";
    homepage = "https://github.com/marshmallow-code/flask-smorest";
    license = lib.licenses.mit;
  };
}
