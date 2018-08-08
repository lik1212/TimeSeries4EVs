%% Time series for electrical vehicles (TS4EV)
%  Zeitreihen für E-Autos
% function Verbrauch_EAuto = TS4EV()
%% Clear start

% close all
clear
path(pathdef);
clc

%% Pfad anpassen

addpath([pwd,'\Input_Files' ])
addpath([pwd,'\Subfunctions'])

%% Zufallsgenerator fixieren

rng(0) % rng(7)

%% Annahmen für konstante Werte

EV_Input.cosphi_EAuto        = 0.9; % kapazitiv
EV_Input.EneVerb_kW_in_1h    = 9.6; % Energieverbrauch in kW bei einer Stunde Fahrt
EV_Input.EneVerb_range_rel   = 0.2; % Band für Energieverbrauch (relativ), z.B. 0.2 -> +-10% um Energieverbrauch
EV_Input.ZSmin               = 10;  % ZSmin - ZeitSchritt in Minuten

%% Auswahl der Szenarien

EV_Input.Auto        = 'BMW i3 3.7 kW';      % Oder: Renault ZOE R90 ...
EV_Input.LadeWahrsch = 'Probst';             % Oder: Ladenverhalten_2015
EV_Input.Verbraucher = 'Person_Typ2';

%% Zufallsgenerator fixieren

rng(0) % rng(7)

%% Main Call

Verbrauch_EAuto = TS4EV(EV_Input);
