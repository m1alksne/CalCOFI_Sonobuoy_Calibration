# Sonobuoy Calibration for SPL Estimation

## Overview

Sonobuoys record underwater sound but rather than storing the signals internally, they transmit them via radio telemetry. To recover sound pressure levels, we apply calibration constants to account for each stage of the system: hydrophone sensitivity, frequency-dependent gain, radio modulation, and A/D conversion.

This repository provides tools and documentation for calibrating received levels from CalCOFI Sonobuoy recordings. The goal is to compute **band-limited Sound Pressure Levels (SPL)** in **dB re 1 µPa** using FFT-based or `pwelch` methods. The provided example is specifically designed for bounding box-based detections generated by [(WhaleMoanDetector)](https://github.com/m1alksne/WhaleMoanDetector) of low-frequency blue and fin whale calls.

## What This Repo Includes
- A MATLAB script to build a calibration struct (`Sonobuoy_calibration_specs.mat`) containing:
  - A/D voltage limits for CalCOFI's Steinberg UR44 
  - ICOM radio modulation correction
  - Sonobuoy hydrophone sensitivity for 53D, 53G, and 57A sonobuoys
  - Interpolated frequency response curves for 53D, 53G, and 57A sonobuoys
- An example SPL calibration script that:
  - Reads in bounding-box-based detections from WhaleMoanDetector
  - Extracts waveform segments
  - Computes band-limited power spectra
  - Applies full calibration
- Sample figures:
  - Frequency response curve JPEGs for each sonobuoy model
  - Histogram of calibrated SPLs for one call type

## Calibration Equations

### Step 1: Compute uncalibrated PSD (e.g., using `pwelch`)
$$
P_{xx}(f) = \text{Power spectrum in counts}^2/\text{Hz}
$$

### Step 2: Convert PSD to dB and apply frequency response correction per bin
$$
P_{xx,\text{dB}}(f) = 10 \log_{10}(P_{xx}(f))
$$

$$
P_{xx,\text{corr,dB}}(f) = P_{xx,\text{dB}}(f) - F(f)
$$

Where \( F(f) \) is the system frequency response in dB at frequency \( f \).

---

### Step 3: Convert corrected PSD back to linear and integrate over frequency
$$
P_{xx,\text{corr}}(f) = 10^{P_{xx,\text{corr,dB}}(f)/10}
$$

$$
P_{\text{band}} = \int_{f_1}^{f_2} P_{xx,\text{corr}}(f) \, df
$$

---

### Step 4: Convert total band-limited power to SPL and apply calibration constants
$$
\text{SPL} = 10 \log_{10}(P_{\text{band}}) + V + S + \text{ICOM}
$$

Where:

- `V` = 20 * log10(ADC volts / bit resolution)
- `S` is the Sonobuoy hydrophone sensitivity (in dB re 1 V/µPa)
- `ICOM` is the radio modulation gain (in dB re kHz/V)

## Example Workflow

1. Load detection timestamps and corresponding WAV file.
2. Use `audioread()` to extract the time segment.
3. Compute power spectrum using `pwelch()` with 90% overlap and Hamming window.
4. Correct the spectrum using the frequency response curve.
5. Integrate and calibrate the band-limited power.
6. Store the final SPL in dB re 1 µPa.

```matlab
[Pxx, F] = pwelch(signal_segment, hamming(fs), round(fs*0.9), fs, fs);
Pxx_dB = 10*log10(Pxx);
freq_indices = (F >= f_min) & (F <= f_max); % band of interest
Pxx_cal_dB = Pxx_dB(freq_indices) - f_dB(freq_indices);  % subtract gain in dB 
Pxx_cal_lin = 10.^(Pxx_cal_dB / 10);  % convert back to linear
SPL_lin = trapz(F(freq_indices), Pxx_cal_lin);  % integrate
SPL = 10*log10(SPL_lin);  % convert back to dB
SPL_calibrated = SPL + V + S + ICOM;  % apply calibration constants. dB re 1 µPa
```
![SPL blue whale](https://github.com/m1alksne/CalCOFI_Sonobuoy_Calibration/blob/main/example_data/Calibrated_SPL_Bm_D_call_CalCOFI_2018_06.jpg)