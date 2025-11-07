# DSD to PCM POC

## Introduction

This is a demo using lib_pdm to convert DSD signal to PCM signal

## Project Structure

* DSD_generator: Firmware that runs on XK-VOICE-SQ66 board to generate DSD signal
* DSD_to_PCM: Firmware that runs on XK-AUDIO-316-MC-AB board to convert DSD signal to PCM signal and play with on-board DAC
* usb_to_dsd: Firmware that runs on XK-AUDIO-316-MC-AB board to play computer host DSD audio through I2S interface with DOP format

## Obtaining the Source Code

```console
git clone --recurse-submodules git@github.com:LeslieXMOS/DSD-to-PCM-POC.git
```

## Test Setup

1. Connect XK-VOICE-SQ66 and XK-AUDIO-316-MC-AB with following pin configuration
    |XK-VOICE-SQ66|XK-AUDIO-316-MC-AB|Function|
    |-------------|------------------|--------|
    |J6 BCLK|J7 DAC D2|DSD BCLK|
    |J6 DATA0|J7 DAC D1|DSD CH0|
    |J6 DATA1|J7 DAC D3|DSD CH1|
    |J2 GND|J39 GND|Common Ground|

2. Run DSD_to_PCM firmware on XK-AUDIO-316-MC-AB

3. Run DSD_generator on XK-VOICE-SQ66
    ```console
    xrun --xscope ./DSD_generator/bin/DSD{MULT}_{BASE}_{FREQ}/DSD_generator_DSD{MULT}_{BASE}_{FREQ}.xe
    ```
    Options for MULT, BASE, FREQ are
    | MULT | BASE | FREQ |
    |------|------|------|
    |64|44100|1000|
    |128|48000|2000|
    |256||4000|
    |512||8000|
    |||19997|

4. You can freely change to run different DSD_generator firmware on XK-VOICE-SQ66, DSD_to_PCM will detect the DSD signal sample frequency and change I2S interface on the fly.