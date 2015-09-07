This attempts on allowing us to run tests on travis/static automatically
generated mock results.

This can be run in two modes

#### Generate cache
Pass all requests to real server, but make a local copy of the result:
```shell
env REAL_SANDBOX_ADDRES="http://127.0.0.1:3001" rackup --port 3002
```

#### Mock mode
Return locally cached results, nil if cached result not available.

For tmc-server, run tests with `rake spec SANDBOX_HOST=127.0.0.1 SANDBOX_PORT=3002`
