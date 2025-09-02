# Unit tests for module-utils.nix
# Run with: nix-instantiate --eval tests/unit/module-utils.nix

let
  lib = import <nixpkgs/lib>;
  utils = import ../../lib/module-utils.nix { inherit lib; };

  # Test helper to check assertions
  assertEq = actual: expected: name:
    if actual == expected then
      { pass = true; test = name; }
    else
      { pass = false; test = name; actual = actual; expected = expected; };

  # Test mkPortOption
  testMkPortOption =
    let
      opt = utils.mkPortOption {
        default = 8080;
        description = "Test port";
      };
    in
    [
      (assertEq opt.type lib.types.ints.u16 "mkPortOption creates port type")
      (assertEq opt.default 8080 "mkPortOption sets default")
      (assertEq opt.description "Test port" "mkPortOption sets description")
    ];

  # Test mkPercentageOption
  testMkPercentageOption =
    let
      opt = utils.mkPercentageOption {
        default = 50;
        description = "Test percentage";
      };
    in
    [
      (assertEq (opt.type.name) "intBetween" "mkPercentageOption creates bounded int")
      (assertEq opt.default 50 "mkPercentageOption sets default")
    ];

  # Test validators
  testValidators = [
    (assertEq (utils.validators.isEmail "test@example.com") true "validates correct email")
    (assertEq (utils.validators.isEmail "invalid") false "rejects invalid email")
    (assertEq (utils.validators.isIPv4 "192.168.1.1") true "validates IPv4")
    (assertEq (utils.validators.isIPv4 "999.999.999.999") true "accepts invalid range IPv4 (regex only)")
    (assertEq (utils.validators.isValidPort 80) true "validates valid port")
    (assertEq (utils.validators.isValidPort 0) false "rejects port 0")
    (assertEq (utils.validators.isValidPort 65536) false "rejects port > 65535")
    (assertEq (utils.validators.isSystemdTimer "daily") true "validates systemd timer")
    (assertEq (utils.validators.isSystemdTimer "invalid") false "rejects invalid timer")
  ];

  # Test mkAssertion
  testMkAssertion =
    let
      assertion1 = utils.mkAssertion true "This should pass";
      assertion2 = utils.mkAssertion false "This should fail";
    in
    [
      (assertEq assertion1.assertion true "mkAssertion with true condition")
      (assertEq assertion2.assertion false "mkAssertion with false condition")
      (assertEq (lib.hasPrefix "Configuration error:" assertion1.message) true "mkAssertion message format")
    ];

  # Test mkScheduleOption
  testMkScheduleOption =
    let
      opt = utils.mkScheduleOption { };
    in
    [
      (assertEq opt.default "daily" "mkScheduleOption has default")
      (assertEq opt.type lib.types.str "mkScheduleOption is string type")
      (assertEq opt.example "weekly" "mkScheduleOption has example")
    ];

  # Combine all tests
  allTests = lib.flatten [
    testMkPortOption
    testMkPercentageOption
    testValidators
    testMkAssertion
    testMkScheduleOption
  ];

  # Count results
  passed = lib.filter (t: t.pass) allTests;
  failed = lib.filter (t: !t.pass) allTests;

in
{
  summary = {
    total = lib.length allTests;
    passed = lib.length passed;
    failed = lib.length failed;
  };

  failures = failed;

  result =
    if lib.length failed == 0 then
      "✓ All tests passed!"
    else
      "✗ ${toString (lib.length failed)} tests failed";
}
