# NixOS Configuration Tests

Comprehensive testing framework for NixOS configuration modules.

## Test Structure

```
tests/
├── unit/           # Unit tests for individual functions
├── integration/    # Integration tests for module interactions
├── vm/            # VM-based tests for services
└── lib/           # Test utilities and helpers
```

## Running Tests

### Quick Test
```bash
# Run all tests (flake, format, unit)
task test
```

### Unit Tests
```bash
# Run unit tests
task test:unit

# Run specific unit test
nix-instantiate --eval tests/unit/module-utils.nix
```

### VM Tests
```bash
# Run all VM tests (resource intensive)
task test:vm

# Run specific VM test
task test:vm:single TEST=backup
task test:vm:single TEST=firewall
```

### Format Check
```bash
# Check formatting
task test:format

# Auto-format
task format
```

## Test Types

### Unit Tests (`unit/`)

Fast, isolated tests for individual functions and utilities.

**Examples:**
- `module-utils.nix` - Tests for module utility functions
- Type validators
- Helper functions

**Running:**
```bash
nix-instantiate --eval tests/unit/module-utils.nix
```

### Integration Tests (`integration/`)

Tests for module interactions and dependencies.

**Examples:**
- Service dependency resolution
- Configuration conflicts
- Module composition

### VM Tests (`vm/`)

Full system tests using NixOS VMs.

**Examples:**
- `backup.nix` - Tests backup service functionality
- `firewall.nix` - Tests firewall rules and security

**Features:**
- Real service testing
- Network interaction
- File system operations
- Service dependencies

## Writing Tests

### Unit Test Template

```nix
# tests/unit/my-test.nix
let
  lib = import <nixpkgs/lib>;
  utils = import ../../lib/my-module.nix { inherit lib; };
  
  assertEq = actual: expected: name:
    if actual == expected then
      { pass = true; test = name; }
    else
      { pass = false; test = name; actual = actual; expected = expected; };
  
  tests = [
    (assertEq (utils.myFunction "input") "expected" "test description")
  ];
  
in {
  result = if all (t: t.pass) tests then
    "✓ All tests passed!"
  else
    "✗ Some tests failed";
}
```

### VM Test Template

```nix
# tests/vm/my-service.nix
import ../lib/test-utils.nix ({ pkgs, lib, ... }:

{
  name = "my-service-test";
  
  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [ ../../modules/services/my-service.nix ];
      
      services.myService = {
        enable = true;
        # Test configuration
      };
    };
  };
  
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    
    # Test service functionality
    machine.succeed("systemctl is-active my-service")
    
    print("✓ Test passed")
  '';
})
```

## Test Utilities

### `lib/test-utils.nix`

Provides common test helpers:
- VM configuration defaults
- Helper functions for common patterns
- Test environment setup

### Available Helpers

```nix
# Wait for service
waitForService machine "service-name" timeout

# Check port
checkPort machine 8080

# Check command output
checkOutput machine "command" "expected output"

# Create test file
createTestFile machine "/path/to/file" "content"
```

## Validation System

### `lib/validators.nix`

Comprehensive validation functions:

**Port Conflict Detection:**
```nix
validators.checkPortConflicts [ 80 443 80 ]  # Throws error
```

**Service Dependencies:**
```nix
validators.serviceDependencies "v2ray" [ "sops" ]
```

**Network Validation:**
```nix
validators.validateNetwork {
  address = "192.168.1.1";
  port = 8080;
}
```

**Path Validation:**
```nix
validators.pathExists "/etc/nixos"
```

## Custom Types

### `lib/module-utils.nix`

Enhanced type system:

```nix
# Network configuration
types.networkConfig

# Service configuration  
types.serviceConfig

# Time window
types.timeWindow

# Memory size with units
types.memorySize  # "2G", "512M"

# URL validation
types.url

# Email validation
types.email

# CIDR networks
types.cidr  # "192.168.1.0/24"

# Domain names
types.domain
```

## CI/CD Integration

### GitHub Actions

```yaml
name: NixOS Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: cachix/install-nix-action@v20
      - run: nix-shell -p go-task --run "task test"
```

### Pre-commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit
task test:unit
task test:format
```

## Best Practices

1. **Test Early**: Run unit tests frequently during development
2. **Test Isolation**: Each test should be independent
3. **Clear Names**: Use descriptive test names
4. **Fast Feedback**: Unit tests before VM tests
5. **Document Failures**: Include helpful error messages
6. **Mock External**: Mock external dependencies when possible

## Troubleshooting

### Test Failures

```bash
# Run with more output
nix-instantiate --eval --strict tests/unit/module-utils.nix

# Check specific test
nix repl
:l tests/unit/module-utils.nix
```

### VM Test Issues

```bash
# Build VM without running
nix-build tests/vm/backup.nix -A driver

# Interactive VM session
nix-build tests/vm/backup.nix -A driver && ./result/bin/nixos-test-driver

# In the Python prompt:
>>> start_all()
>>> machine.wait_for_unit("multi-user.target")
>>> machine.succeed("your-command")
```

### Resource Issues

VM tests require significant resources:
- At least 4GB RAM available
- 10GB+ disk space
- KVM acceleration recommended

## Coverage

Current test coverage:
- ✅ Module utilities
- ✅ Backup service
- ✅ Firewall configuration
- ⏳ Network services
- ⏳ Performance modules
- ⏳ Security hardening

## Contributing

When adding new modules:
1. Add unit tests for helper functions
2. Add VM test for service functionality
3. Update this README
4. Ensure all tests pass before committing