# Health Export

An iOS app that sends a daily plain-text summary of your Apple Health data to a webhook. It's built to feed an AI assistant, such as a Grok Bot routine, that reads the text as is: no parser needed.

## What it does

- Once a day, after a time you choose (9:00 by default), it POSTs yesterday's summary plus that night's sleep to your endpoint. The summary covers steps, active energy, exercise minutes and workouts; average and resting heart rate and HRV; deep, core and REM sleep with awakenings; weight, blood oxygen, and any of about 60 Health data types you enable.
- Totals come from HealthKit statistics, so they match the Health app with no double counting between iPhone and Apple Watch.
- It runs in the background through HealthKit background delivery and `BGAppRefreshTask`. If the phone misses some days, it catches up on up to 7 of them, one message per day.
- The request body is `{"text": "…"}`, usually 500–1,000 characters, sent with Bearer, Basic or no authentication.
- A preview screen shows exactly what will be sent. "Send summary now" and "Test connection" buttons cover manual runs.

The app UI and the summary are in Spanish. See [`ejemplo-resumen.txt`](ejemplo-resumen.txt) for a sample and [`FORMATO.md`](FORMATO.md) for the full description.

## Build

Requires Xcode 26, iOS 17+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open HealthExport.xcodeproj
```

Set your own `DEVELOPMENT_TEAM` and bundle identifier in `project.yml` before building for a device.

## Test receiver

```sh
python3 receiver.py 8787 mysecret
```

It prints each summary, saves it to `received/` and answers 401 if the Bearer token doesn't match. In the simulator, the "Insertar datos de prueba" button adds sample steps, heart rate and a night of sleep.
