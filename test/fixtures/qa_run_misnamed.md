# Run record — a record whose name drops the device's full slug

This fixture is copied into qa/runs/ under a misnamed file by
tools/mutation_check.py; the test-plan guard must refuse the name.

- Build: vdev · BUILD dev
- Device: fixture
- Android / One UI: n/a
- Hardware or emulator: n/a
- AVD and image: n/a
- Runs: R1
- Run by: agent

| check | result | bug |
|---|---|---|
| T001 | pass | |
