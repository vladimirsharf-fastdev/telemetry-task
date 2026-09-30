# Telemetry service

## Context

A company has a fleet of devices: mini-robots about the size of an ant,
made for berry-picking. There are many of them, in order of hundreds of thousands,
or even millions. 

The robots report telemetry to a nearby hub, which aggregates the records and forwards them to a central service. One TCP connection per hub. 

Operators need to see the telemetry for any selected robot in real time with minimal latency. 

## The Task & Conditions

Your task is the central service: collect the data from hubs and serve the latest data point of any device over an HTTP API.

Requirements:
- Performance (single core):
    - ingest up to ~10M points / sec while simultaneously reading ~10K requests / sec.
    - 95% latency for the reads is under 100 ms, under load above.
- Persistence: the latest records survive a restart of the service.

Conditions:
- A working prototype (source code and executable) is expected by the end of the interview.
- You can prepare it in advance or during the interview, it doesn't matter as long as the task is completed.
- You can use any tool you want (including AI) before and during the interview. The only limitation: use the current .NET version.
- You should be able to explain the code and every design decision.

## The protocol

The wire protocol between the hubs and the service is specified in [`specs/protocol.md`](specs/protocol.md): batch and record layout, status flags and sequence rules.

## The API

The HTTP API is specified in [`specs/openapi.yaml`](specs/openapi.yaml). One endpoint:

- `GET /devices/{deviceId}/latest` returns the newest record.

Fixed-point wire fields are returned in units. Position fields are `null` when the record has no fix.

## Tools

### Hub emulator

`tools/device-emulator/` emulates the hubs. It generates random records for a range of devices, packs them as the protocol specifies, and streams them over TCP. One thread per hub connection, disjoint device ranges per connection.

```
device-emulator.exe                    # reads device-emulator.toml next to the exe
device-emulator.exe my-config.toml     # or the file given
```

### Read load

[oha](https://github.com/hatoo/oha), `tools/read-load.ps1` runs it with the right parameters:

```
.\tools\read-load.ps1                        # 30 s, 256 connections, random ids 0..199999
.\tools\read-load.ps1 -Seconds 60 -Rate 20000 # the read requirement: fixed 20k requests/s
```

Run it while the emulator is streaming to measure reads under ingest.


### Running on a single core

The performance figures are for the service on one logical CPU. Start it that way from cmd:

```
set DOTNET_PROCESSOR_COUNT=1
start /affinity 1 YourService.exe
```

`/affinity` takes a hex CPU mask: `1` is the first logical CPU. `DOTNET_PROCESSOR_COUNT` makes the runtime size its thread pool and GC for one processor; the mask alone does not. On a hybrid CPU pick a performance core: on Intel the P-cores are the low-numbered CPUs.
