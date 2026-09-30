# Hub protocol

A hub sends a byte stream of **batches**, back to back, no framing between them. One batch carries the records of **one device**. The stream ends when the hub closes the connection. A hub reconnects after a network failure and continues where it left off.

All integers are **little-endian**. All offsets are bytes.

## Batch

| Offset | Type | Field | Meaning |
|---|---|---|---|
| 0 | u16 | Version | Always 1. Reject anything else. |
| 2 | u16 | BodyLength | Bytes in the body, 0 to 16384. |
| 4 | u32 | DeviceId | Which device the batch belongs to. |
| 8 | u64 | BatchSequence | Per device, strictly increasing. |
| 16 | bytes | Body | BodyLength bytes: the records. |
| 16 + BodyLength | 16 bytes | Tag | Reserved: the production protocol carries an authentication tag here. All zeros in this task, skip it. |

Header size is 16, tag size is 16, so a batch is `32 + BodyLength` bytes. The body is a whole number of records: `BodyLength % 48 == 0`, at most 341 records.

## Record

48 bytes each. No device id: the batch names the device.

| Offset | Type | Field | Meaning |
|---|---|---|---|
| 0 | u16 | Version | Always 1. |
| 2 | u16 | Status | Flags, see below. |
| 4 | u16 | HorizontalAccuracyCm | Position accuracy in centimetres. 0 without a fix. |
| 6 | u16 | reserved | Zero. |
| 8 | u64 | Sequence | Per device, strictly increasing. |
| 16 | i64 | TimestampUnixMicros | Device clock, microseconds since the Unix epoch. |
| 24 | f32 | Temperature | Degrees Celsius. |
| 28 | f32 | Voltage | Volts. |
| 32 | i32 | LatitudeE7 | Degrees times 10^7. 0 without a fix. |
| 36 | i32 | LongitudeE7 | Degrees times 10^7. 0 without a fix. |
| 40 | i32 | AltitudeCm | Centimetres above the WGS84 ellipsoid. 0 without a fix. |
| 44 | 4 bytes | reserved | Zero. |

Status flags:

| Bit | Name |
|---|---|
| 0 | PositionValid |
| 1 | OnBattery |
| 2 | Charging |
| 3 | SensorFault |
| 4 | ClockUnsynced |

Position fields are meaningful only when `PositionValid` is set.

## Sequence rules

- `BatchSequence` is strictly increasing per device. A batch with a sequence not above the last accepted one for that device is a replay or a reorder: reject it.
- `Sequence` inside the records is strictly increasing per device as well. A record that is not newer than the newest one is ignored.
- A hub reconnect does not reset either sequence. The sequences must survive the reconnect on your side too, or a captured batch can be replayed after every reconnect.
