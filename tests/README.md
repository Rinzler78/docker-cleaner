# Test Scripts - Execution Order

This directory contains the testing framework for docker-cleaner. Scripts are numbered to indicate their logical execution order and dependencies.

## Numbering Convention

### Foundation Scripts (0x series)
Scripts that provide base functionality for test resource management:

- **01-setup-test-resources.sh** - Create Docker test resources (containers, images, volumes, networks)
- **02-validate-cleanup.sh** - Validate cleanup operations with before/after resource counting
- **03-cleanup-test-resources.sh** - Remove all test resources (cleanup foundation)

### Test Execution Scripts (1x series)
Scripts that test docker-cleaner functionality in different execution contexts:

- **11-test-local-cleanup.sh** - Test cleanup script execution directly in terminal
- **12-test-container-cleanup.sh** - Test docker-cleaner Docker image (containerized execution)
- **13-test-remote-contexts.sh** - Test cleanup on remote Docker hosts via contexts

### Master Test Runner (9x series)
Orchestration script that coordinates all test types:

- **99-run-all-tests.sh** - Master test runner that executes all test suites with comprehensive reporting

## Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Test Execution Flow                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Master Runner (99)                                             │
│       │                                                          │
│       ├─→ Local Tests (11)                                      │
│       │     ├─→ Setup (01) ────→ Test ────→ Cleanup (03)       │
│       │     ├─→ Setup (01) ────→ Test ────→ Cleanup (03)       │
│       │     └─→ Setup (01) ────→ Test ────→ Cleanup (03)       │
│       │                                                          │
│       ├─→ Container Tests (12)                                  │
│       │     └─→ Setup (01) ────→ Test ────→ Cleanup (03)       │
│       │                                                          │
│       └─→ Remote Tests (13)                                     │
│             └─→ Setup (01) ────→ Test ────→ Cleanup (03)       │
│                                                                  │
│  Validation (02) can be used at any point to verify resources   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Run All Tests
```bash
./tests/99-run-all-tests.sh
```

### Run Specific Test Type
```bash
# Local tests only
./tests/99-run-all-tests.sh --only-local

# Container tests only
./tests/99-run-all-tests.sh --only-container

# Remote tests only
./tests/99-run-all-tests.sh --only-remote
```

### Run Tests on Specific Context
```bash
./tests/99-run-all-tests.sh --context remote-nas
```

### Manual Test Execution
```bash
# 1. Create test resources
./tests/01-setup-test-resources.sh

# 2. Run local cleanup test
./tests/11-test-local-cleanup.sh

# 3. Clean up test resources
./tests/03-cleanup-test-resources.sh
```

## Test Resource Isolation

All test scripts use the label `test-cleanup=true` to ensure complete isolation from production resources:

- **Foundation scripts** (01, 03) manage resources labeled with `test-cleanup=true`
- **Test execution scripts** (11-13) only operate on labeled test resources
- **Production resources** are never affected by testing

## Dependencies

### Foundation Scripts
- **01** → Creates resources → Used by **11**, **12**, **13**
- **02** → Validates cleanup → Can be used independently
- **03** → Removes resources → Used by **11**, **12**, **13**

### Test Execution Scripts
- **11** → Depends on: **01**, **03**
- **12** → Depends on: **01**, **03**
- **13** → Depends on: **01**, **03**

### Master Runner
- **99** → Orchestrates: **11**, **12**, **13**

## Documentation

For comprehensive testing documentation, see:
- [docs/testing-guide.md](../docs/testing-guide.md) - Complete testing guide with examples
- [README.md](../README.md) - Project overview and quick start
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines including testing requirements

## Naming Convention

Scripts follow the pattern: `NN-descriptive-name.sh`

- **NN**: Two-digit number indicating execution order and category
- **descriptive-name**: Clear description of script purpose
- **.sh**: Shell script extension

This numbering system ensures:
1. ✅ Clear execution order when listing scripts (`ls tests/`)
2. ✅ Logical grouping by functionality (0x, 1x, 9x)
3. ✅ Easy identification of dependencies
4. ✅ Scalability for future test additions

## Test Coverage

The test framework provides comprehensive coverage across three execution contexts:

- **Local Terminal**: Direct script execution (~15+ assertions per test)
- **Docker Container**: Containerized execution with non-root security
- **Remote Contexts**: Multi-host deployment validation

**Estimated Coverage**: ~80-85% of cleanup operations

For detailed coverage metrics, see the project documentation.
