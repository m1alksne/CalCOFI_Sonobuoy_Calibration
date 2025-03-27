% MNA (3/27/25)
% -------------------------------------------------------------
% Script to generate a universal struct containing calibration 
% specifications for different Sonobuoy types (57A, 53D, 53G).
% These specifications include A/D Steinberg system voltage, radio calibration 
% (ICOM), Sonobuoy hydrophone sensitivity, and frequency response curves.
% Calibration values were provided by JAH.
% -------------------------------------------------------------

%% 1. Initialize main structs for DIFAR and OMNI Sonobuoy types
DIFAR = struct();
OMNI = struct();

%% 2. Add core calibration parameters for each buoy type
% These include:
% - volts: Maximum voltage range of the A/D converter (Steinberg)
% - ICOM: Radio modulation factor in dB (46 dB corresponds to 0.049 V/kHz)
% - SB_sensitivity: Sonobuoy sensitivity in dB re 1 µPa/kHz, 
%   derived from 122 dB re 1 µPa - 20*log10(FM deviation in kHz)

DIFAR.volts = 5;             % Steinberg A/D converter voltage range
DIFAR.ICOM = 46;             % Radio modulation: 20*log10(1 / 0.049 V/kHz) ? 46 dB
DIFAR.SB_sensitivity = 90;   % 122 dB re 1 µPa - 20*log10(40 kHz deviation)

OMNI.volts = 5;
OMNI.ICOM = 46;
OMNI.SB_sensitivity = 94;    % 122 dB re 1 µPa - 20*log10(25 kHz deviation)

%% 3. Define Sonobuoy frequency response curves
% These are band-specific system gain values (in dB) from manufacturer plots (provided by JAH).
% Response curves are interpolated to 1 Hz spacing over 0–10,000 Hz.

% 3a. Frequencies used to define raw curve shape (Hz)
freq = [1 10 100 1000 10000]; % Key frequencies pulled from response plots
f = (0:1:10000);              % Interpolation target: 1 Hz resolution

% 3b. DIFAR 53G (used for both DIFAR and OMNI)
DIFAR.i53G.f = f';
DIFAR.i53G.response_dB = interp1(freq, [-40 -17 0 20 -22], f, 'linear', 'extrap')';

OMNI.i53G.f = f';
OMNI.i53G.response_dB = interp1(freq, [-40 -17 0 20 -22], f, 'linear', 'extrap')';

% 3c. DIFAR 53D
DIFAR.i53D.f = f';
DIFAR.i53D.response_dB = interp1(freq, [-31 -18 0 20 -40], f, 'linear', 'extrap')';

% 3d. OMNI 57A
OMNI.i57A.f = f';
OMNI.i57A.response_dB = interp1(freq, [-35 -14 0 17 20], f, 'linear', 'extrap')';

% -------------------------------------------------------------
% Output:
% DIFAR and OMNI are structs with nested fields:
% - volts: A/D full-scale voltage (Volts)
% - ICOM: Radio modulation correction (dB)
% - SB_sensitivity: Hydrophone sensitivity (dB re 1 µPa/kHz)
% - i53X.response_dB: Frequency response (dB) at 1 Hz resolution
% -------------------------------------------------------------

save('L:\CalCOFI\CalCOFI_Sonobuoy\Acoustic_density_estimation\Sonobuoy_calibration\Sonobuoy_calibration_specs.mat', 'DIFAR', 'OMNI');

% How to apply calibration to compute calibrated Sound Pressure Level (SPL):
%
%       A = X + V + S + ICOM - F
%
% Where:
% A     = Calibrated SPL (dB re 1 µPa)          ? final sound pressure level
% X     = Uncalibrated SPL (dB re counts²/Hz)   ? estimated from FFT magnitude spectrum
% V     = 20*log10(ADC full-scale voltage / digital resolution)
%       = 20*log10(5 / 2^24) for a 5 V, 24-bit A/D system
% S     = Hydrophone sensitivity (dB re 1 V/µPa)
% ICOM  = Radio modulation correction (dB re kHz/V)
% F     = System frequency response (dB re Hz) — applied per frequency bin
%
% Notes:
% - X is computed from a time-averaged power spectrum (e.g., overlapping FFTs with windowing using pwelch).
% - Power spectra should be integrated over the frequency band of interest (e.g., bounding box frequency coordinates or pre-defined by user).
% - All terms are in decibels (logarithmic units).
% - F should be subtracted per frequency bin **before** integrating.
% - After integration (in linear units), convert back to dB: A = 10*log10( ?(X - F)_linear )
