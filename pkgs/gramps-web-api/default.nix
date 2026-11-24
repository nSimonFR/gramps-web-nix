{
  lib,
  buildPythonPackage,
  fetchFromGitHub,

  setuptools,
  setuptools-scm,

  # TODO: remove
  gobject-introspection,
  gtk3,
  wrapGAppsHook3,

  alembic,
  authlib,
  bleach,
  boto3,
  celery,
  click,
  ffmpeg-python,
  flask,
  flask-caching,
  flask-compress,
  flask-cors,
  flask-jwt-extended,
  flask-limiter,
  flask-sqlalchemy,
  gramps,
  cryptography,
  flask-smorest,
  gramps-gedcom7,
  gramps-object-query-language,
  gramps-ql,
  jsonschema,
  limits,
  marshmallow,
  orjson,
  pdf2image,
  pillow,
  psycopg2,
  py-vapid,
  pygobject3,
  pytesseract,
  pywebpush,
  redis,
  requests,
  sqlalchemy,
  typing-extensions,
  unidecode,
  waitress,
  webargs,
  yclade,

  pytestCheckHook,
  pyyaml,
  writableTmpDirAsHomeHook,
}:

buildPythonPackage rec {
  pname = "gramps-web-api";
  version = "3.25.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "gramps-project";
    repo = "gramps-web-api";
    tag = "v${version}";
    hash = "sha256-zeb3n3VIZ7tlr/e5yYzmKgfkYhoj/JqMGEqZ2Ry3d6o=";
  };

  patches = [
    # fixes TestMediaArchiv::test_create_archive which tries to use an example
    # zip file from the nix store (which has non-zip compatible timestamps)
    ./remove-zip-timestamp-strictness.patch
    # The frontend starts an OIDC login without a tree, which a multi-tree
    # setup rejected ("tree is required"), so SSO could never sign in. A linked
    # account keeps its own tree; an unlinked one is refused, not created.
    ./oidc-multi-tree-login.patch
  ];

  build-system = [
    setuptools
    setuptools-scm
  ];

  # TODO: don't have to specify again
  nativeBuildInputs = [
    gobject-introspection
    gtk3
    wrapGAppsHook3
  ];

  # boto3: upstream over-pins. pygobject: nixpkgs 25.11 ships 3.54.5 but
  # gramps-web-api pins <=3.50.0 (compatible in practice).
  # pywebpush: nixpkgs has 2.3, upstream wants >= 2.5 (only the push
  # notification sender uses it).
  pythonRelaxDeps = [ "boto3" "pygobject" "pywebpush" ];
  # psycopg2-binary: the same module as nixpkgs' psycopg2.
  pythonRemoveDeps = [ "psycopg2-binary" ];

  dependencies = [
    alembic
    authlib
    bleach
    boto3
    celery
    click
    ffmpeg-python
    flask
    flask-caching
    flask-compress
    flask-cors
    flask-jwt-extended
    flask-limiter
    flask-sqlalchemy
    gramps
    cryptography
    flask-smorest
    gramps-gedcom7
    gramps-object-query-language
    gramps-ql
    jsonschema
    limits
    marshmallow
    orjson
    pdf2image
    pillow
    psycopg2
    py-vapid
    pygobject3
    pytesseract
    pywebpush
    redis # celery[redis] broker/result backend — the redis python client
    requests
    sqlalchemy
    typing-extensions
    unidecode
    waitress
    webargs
    yclade

    # NOTE: the upstream PR (#417806) also lists accelerate/openai/
    # sentence-transformers here (its `[ai]` extras). Dropped entirely — they
    # pull in PyTorch, far too heavy for the RPi5, and Gramps Web runs fine
    # without semantic search / chat.
  ] ++ bleach.optional-dependencies.css;

  # The wheel leaves out the user-DB migrations; `gramps_webapi user migrate`
  # runs `alembic upgrade head` and needs alembic.ini in its working directory.
  postInstall = ''
    mkdir -p $out/share/gramps-web-api
    cp -r alembic.ini alembic_users $out/share/gramps-web-api/
  '';

  nativeCheckInputs = [
    pytestCheckHook
    pyyaml
    writableTmpDirAsHomeHook
  ];

  preCheck = ''
    # don't try to download a semantic search model from the internet during testing
    substituteInPlace "tests/test_endpoints/__init__.py" \
      --replace-fail '"paraphrase-albert-small-v2"' '""'
  '';

  disabledTestPaths = [
    # mock_s3 is not found in moto 5.0.0+
    "tests/test_s3.py"
    "tests/test_endpoints/test_s3.py"

    # Requires a semantic search model be present
    "tests/test_endpoints/test_chat.py"
  ];

  disabledTests = [
    # assert the "tree is required" refusal that oidc-multi-tree-login.patch removes
    "test_login_requires_tree"
    "test_callback_without_login_is_refused"

    # network access needed
    "test_get_faces"
    "test_get_faces_requires_token"

    # the test wants to load some fonts
    "test_get_ocr"

    # pytest-celery is not packaged in nixpkgs
    "test_task_noauth"
    "test_task_nonexistant"
  ];

  pythonImportsCheck = [
    "gramps_webapi"
  ];

  meta = {
    description = "RESTful web API for Gramps - backend of Gramps Web";
    homepage = "https://github.com/gramps-project/gramps-web-api";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ tomasajt ];
  };
}
