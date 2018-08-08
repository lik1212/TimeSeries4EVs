function Verbrauch_EAuto = TS4EV(EV_Input)
%% Function to create time series for electical vehicals.

%% Einstellungen auslessen

cosphi_EAuto        = EV_Input.cosphi_EAuto;
EneVerb_kW_in_1h    = EV_Input.EneVerb_kW_in_1h;
EneVerb_range_rel   = EV_Input.EneVerb_range_rel;
ZSmin               = EV_Input.ZSmin;
Auto                = EV_Input.Auto;
LadeWahrsch         = EV_Input.LadeWahrsch;
Verbraucher         = EV_Input.Verbraucher;

%% Zeitraum definieren

ZSmin_in_Stunde         = 60/ZSmin;
Erster_Zeitpunkt        = datetime('01.01.2015 00:00:00','Format','dd.MM.yyyy HH:mm:ss');
Letzter_Zeitpunkt       = datetime('31.12.2015 23:50:00','Format','dd.MM.yyyy HH:mm:ss');
T_Vektor(:,1)           = Erster_Zeitpunkt : minutes(ZSmin) : Letzter_Zeitpunkt;
Stunden_fur_Zeitpunkte  = hour (T_Vektor);
num_Zeitpunkte          = numel(T_Vektor);


%% Fahrzeug Eigenschaften einlesen

File_EV             = 'Fahrzeug_Eigenschaften.xlsx';
[~, ~, EV_Daten]    = xlsread(File_EV,Auto);
Batterie_Kapa       = EV_Daten{2,2};                            % in kWh
Anzahl_Leiter       = EV_Daten{11,2};
Lade_Leistung_max   = EV_Daten{12,2};                           % in kW
Lade_Leistung_avg   = EV_Daten{13,2};                           % in kW
Lade_Leistung_band  = Lade_Leistung_max - Lade_Leistung_avg;    % in kW

%% Lade Wahrscheinlichkeiten einlesen

File_Lade               = 'Lade_Wahrscheinlichkeiten';
[~, ~, Lade_Daten]      = xlsread(File_Lade,LadeWahrsch);
Lade_Stat           	= cell2mat(Lade_Daten(2:end,:));
Lade_Stat_gewicht       = Lade_Stat;
Lade_Stat_gewicht(:,2)  = Lade_Stat(:,2)/max(Lade_Stat(:,2));

%% Verbraucher Verhalten einlesen

File_Verbrauch          = 'Verbraucher_Verhalten';
[~, ~, Verbrauch_Daten] = xlsread(File_Verbrauch,Verbraucher);
Verbrauch_Daten         = cell2mat(Verbrauch_Daten(2:end,:));

%% Initialisierung von Vektoren

SoC                         = zeros(num_Zeitpunkte,1);  % State of charge
LeistungBezogen             = zeros(num_Zeitpunkte,1);
LadeBeginn_Zeitpunkte       = false(num_Zeitpunkte,1);
Lade_Zeitpunkte             = false(num_Zeitpunkte,1);
Auto_wird_passiv_benutzt    = false(num_Zeitpunkte,1);
Auto_wird_aktiv_benutzt     = false(num_Zeitpunkte,1);
SoC_wurde_negativ           = false(num_Zeitpunkte,1);

%% State of charge (SoC) zum 1. Zeitpunkt

SoC(1) = ((randn+3)/6)*Batterie_Kapa;
if SoC(1) < 0
    SoC(1) = 0;
end
if SoC(1) > Batterie_Kapa
    SoC(1) = Batterie_Kapa;
end

%% Abhängigkeit der Ladewahrscheinlichkeit vom SoC
% Eine Gerade (2 Punkte) wird definiert

SoC_1      = 0.3;                                 	% Wenn SoC auf  30%
Laden_1    = 1;                                     % Wahrscheinlichkeit für Laden = 100%.
SoC_2      = 1;                                     % Wenn SoC auf 100%
Laden_2    = 0;                                     % Wahrscheinlichkeit für Laden = 0%.
Slope_Gew1 = (Laden_1 - Laden_2) / (SoC_1 - SoC_2); % Steigung für Gewicht = 1

%% Über alle Zeitpunkte
for k = 1:num_Zeitpunkte-1
    if SoC(k) < 0                                                           % Falls SoC negativ (Beginn)
        SoC(k)               = 0;                                               % Auto muss außer Haus geladen werden.
        SoC_wurde_negativ(k) = true;                                            % Aber "worst case", wenn Auto nachhause kommt SoC = 0
    end
    if Auto_wird_aktiv_benutzt(k) || Auto_wird_passiv_benutzt(k)            % Falls Auto benutzt wird (aktiv oder passiv)
        if Auto_wird_aktiv_benutzt(k)                                           % Falls Auto aktiv benutzt wird
            SoC(k+1) = SoC(k) -  EneVerb_kW_in_1h * ZSmin/60 * ...                  % SoC berechnen, Energieverbrauch auf Zeitschritte
                (1 + EneVerb_range_rel * (rand - 0.5));                             % angepasst, Band für Energieverbrauch berücksichtigen
        else                                                                    % Falls Auto passiv benutzt wird
            SoC(k+1) = SoC(k);                                                      % SoC bleibt gleich
        end
    else                                                                    % Falls Auto nicht benutzt wird
        if Lade_Zeitpunkte(k)                                                   % Falls lade Zeitpunkt
            LeistungBezogen(k) = ...                                                % Ladeleistung bestimmen:
                Lade_Leistung_avg + ...                                             % Werte zwischen:
                Lade_Leistung_band * (2 * rand  - 1);                               % [Mittelwert - Lade_Leistung_band, Mittelwert + Lade_Leistung_band]
            SoC(k+1) = SoC(k) + LeistungBezogen(k) / ZSmin_in_Stunde;               % SoC berechnen (Es wird geladen)
            if SoC(k+1) < Batterie_Kapa                                             % Falls Batterie nicht voll:
                Lade_Zeitpunkte(k+1) = true;                                            % Normales laden zum nächsten Zeitpunkt
            else                                                                    % Falls Batterie voll:
                Lade_Zeitpunkte(k+1) = false;                                           % Nicht laden zum nächsten Zeitpunkt
                SoC(k+1) = Batterie_Kapa;                                               % SoC auf Batteriekapazität begrenzen
            end
        else                                                                    % Wird nicht geladen
            SoC(k+1) = SoC(k);                                                      % SoC bleibt gleich
        end
    end
    if ~Auto_wird_aktiv_benutzt(k+1) && ~Auto_wird_passiv_benutzt(k+1)      % Falls auf Basic vom jetzigen Zeitpunkt, das Auto zum nächsten Zeitpunkt nicht benutzt wird
        % Bestimmen ob Auto zum nächsten Zeitpunkt begonnen wird zu benutzen
        WochenTag = weekday(T_Vektor(k+1));                                     % Wochentag bestimmen
        switch WochenTag
            case num2cell(2:6)  % Werktag
                Ver_Spalte = 2:5;
            case 7              % Samstag
                Ver_Spalte = 6:9;
            case 1              % Sonntag
                Ver_Spalte = 10:13;
        end
        Stunde_kp1 = Stunden_fur_Zeitpunkte(k+1);                               % Uhrzeit in Stunden für nächsten Zeitpunkt (k + 1)
        Wahrschein_benutzt_Stunde = Verbrauch_Daten(...                         % Wahrscheinlichkeit das Auto in dieser Stunden begonnen wird zu benutzen
            Verbrauch_Daten(:,1) == Stunde_kp1,Ver_Spalte(1));
        Wahrschein_benutzt_ZS       = ...                                       % Um die richtige Wahrscheinlichkeit für die Zeitschritte zu bestimmen,
            1 - nthroot(1 - Wahrschein_benutzt_Stunde, ZSmin_in_Stunde);        % muss das Verhältnis von Stunden zu Zeitschritte bestimmt werden
        if Wahrschein_benutzt_ZS >= rand                                        % Falls Auto zum nächsten Zeitpunkt begonnen wird zu benutzen
            Stunden_aktiv_hin       = Verbrauch_Daten(...                           % Hinfahrt: Stunden aktiv benutzt
                Verbrauch_Daten(:,1) == Stunde_kp1,Ver_Spalte(2));
            ZP_aktiv_hin            = Stunden_aktiv_hin * ZSmin_in_Stunde;          % Hinfahrt: Zeitpunkte aktiv benutzt
            Auto_wird_aktiv_benutzt(...
                k + 1 : ...
                k + ZP_aktiv_hin)   = true;
            Stunden_passiv          = Verbrauch_Daten(...                           % Aufenthaltszeit: Stunden passiv benutzt
                Verbrauch_Daten(:,1) == Stunde_kp1,Ver_Spalte(3));
            ZP_passiv               = Stunden_passiv * ZSmin_in_Stunde;             % Aufenthaltszeit: Zeitpunkte passiv benutzt:
            Auto_wird_passiv_benutzt(...
                k + ZP_aktiv_hin + 1 : ...
                k + ZP_aktiv_hin + ZP_passiv)   = true;
            Stunden_aktiv_zuruck    = Verbrauch_Daten(...                           % Rückfahrt: Stunden aktiv benutzt
                Verbrauch_Daten(:,1) == Stunde_kp1,Ver_Spalte(4));
            ZP_aktiv_zuruck         = Stunden_aktiv_zuruck * ZSmin_in_Stunde;       % Rückfahrt: Zeitpunkte aktiv benutzt
            Auto_wird_aktiv_benutzt(...
                k + ZP_aktiv_hin + ZP_passiv + 1 : ...
                k + ZP_aktiv_hin + ZP_passiv + ZP_aktiv_zuruck) = true;
            LadeBeginn_Zeitpunkte(...                                               % Verbiete Ladebeginnzeitpunkte falls Auto benutzt wird
                k + 1:...
                k + ZP_aktiv_hin + ZP_passiv + ZP_aktiv_zuruck) = false;
            Lade_Zeitpunkte(...                                                     % Verbiete Ladezeitpunkte falls Auto benutzt wird
                k + 1:...
                k + ZP_aktiv_hin + ZP_passiv + ZP_aktiv_zuruck) = false;
        else                                                                    % Falls Auto zum nächsten Zeitpunkt nicht begonnen wird zu benutzen
            if ~Lade_Zeitpunkte(k)                                                  % Falls Auto zum jetzigen Zeitpunkt nicht geladen hat
                % Bestimmen ob Auto zum nächsten Zeitpunkt anfangen wird zu laden
                SoC_rel             = SoC(k)/Batterie_Kapa;                         % Relative Angabe für SoC (Wert zwischen 0 bis 1)
                Gewicht4Slope       = Lade_Stat_gewicht(...                         % Gewicht der Steigung (Wert zwischen 0 und 1) zwischen der Funktion
                    Lade_Stat_gewicht(:,1) == Stunde_kp1,2);                        % der Wahrscheinlichkeit das Auto beginnt zu laden und dem SoC_rel
                Slope_GewReal       = Slope_Gew1 / Gewicht4Slope;                 	% Gewichtete Steigung der Funktion WahrshLadenbeginn = function(SoC_rel)
                Y_AchsenAbsch       = Laden_1 - Slope_GewReal * SoC_1;              % Y-Achsenabschnitt   der Funktion WahrshLadenbeginn = function(SoC_rel)
                Wahrsh_Ladebeg_hour = ...                                           % Wahrscheinlichkeit das Auto beginnt zu laden für diese Stunde
                    Slope_GewReal * SoC_rel + Y_AchsenAbsch;
                Wahrsh_Ladebeg_hour(Wahrsh_Ladebeg_hour > 1) = 1;                   % Falls > 1 (100%) auf 1 (100%) setzen, bedingt durch n-te Wurzel
                Wahrsh_Ladebeg_ZS = ...
                    1 - nthroot(1 - Wahrsh_Ladebeg_hour,ZSmin_in_Stunde);           % Wahrscheinlichkeit das Auto beginnt zu laden für diesen Zeitschritt 
                if Wahrsh_Ladebeg_ZS >= rand                                            % Wird das Auto zum nächsten Zeitpunkt anfangen zu laden
                    LadeBeginn_Zeitpunkte(k+1)   = true;
                    Lade_Zeitpunkte(k+1)         = true;
                end
            end
        end
    end
end

%% Benutzer Profile können auch über Zeitpunkte gehen, also zuschneiden

Auto_wird_aktiv_benutzt  = Auto_wird_aktiv_benutzt (1:num_Zeitpunkte);
Auto_wird_passiv_benutzt = Auto_wird_passiv_benutzt(1:num_Zeitpunkte);

%% Leistungsvektor erstellen

Verbrauch_EAuto = table;
if Anzahl_Leiter == 1 	% Einphasiger Verbraucher
    Phase_Verbrauch = randi([1 3]);
    for k_Pha = 1:3
        if k_Pha == Phase_Verbrauch
            Verbrauch_EAuto.(['P_L',num2str(k_Pha)]) = ...
                LeistungBezogen;
            Verbrauch_EAuto.(['Q_L',num2str(k_Pha)]) = ...
                - LeistungBezogen * tan(acos(cosphi_EAuto));
        else
            Verbrauch_EAuto.(['P_L',num2str(k_Pha)]) = zeros(num_Zeitpunkte,1);
            Verbrauch_EAuto.(['Q_L',num2str(k_Pha)]) = zeros(num_Zeitpunkte,1);
        end
    end
else                    % Dreiphasiger Verbraucher
    for k_Pha = 1:3
        Verbrauch_EAuto.(['P_L',num2str(k_Pha)]) = ...
            LeistungBezogen/3;
        Verbrauch_EAuto.(['Q_L',num2str(k_Pha)]) = ...
            LeistungBezogen/3;
    end
end

%% Figure

figure('units','normalized','outerposition',[0 0 1 1])

subplot(1,5,1)
SoC_in_Per = SoC/Batterie_Kapa;
plot(T_Vektor,SoC_in_Per)
title('SoC')

subplot(1,5,2);
Lade_Zeitpunkte_in_T_Vektor = T_Vektor;
Lade_Zeitpunkte_in_T_Vektor(~Lade_Zeitpunkte) = NaT;
histogram(hour(Lade_Zeitpunkte_in_T_Vektor),'Normalization','probability')
xlabel('Uhrzeit in h');
ylabel('Relative Häufigkeit über alle Zeitpunkte');
xlim([-1 24]);
xticks([0:4:20,23]);
title('Ladezeitpunkte')

subplot(1,5,3);
LadeBeginn_Zeitpunkte_in_T_Vektor = T_Vektor;
LadeBeginn_Zeitpunkte_in_T_Vektor(~LadeBeginn_Zeitpunkte) = NaT;
histogram(hour(LadeBeginn_Zeitpunkte_in_T_Vektor),'Normalization','probability')
xlabel('Uhrzeit in h');
ylabel('Relative Häufigkeit über alle Zeitpunkte');
xlim([-1 24]);
xticks([0:4:20,23]);
title('Ladebeginn-Zeitpunkte')

subplot(1,5,4);
Auto_wird_aktiv_benutzt_in_T_Vektor = T_Vektor;
Auto_wird_aktiv_benutzt_in_T_Vektor(~Auto_wird_aktiv_benutzt) = NaT;
histogram(hour(Auto_wird_aktiv_benutzt_in_T_Vektor),'Normalization','probability')
xlabel('Uhrzeit in h');
ylabel('Relative Häufigkeit über alle Zeitpunkte');
xlim([-1 24]);
xticks([0:4:20,23]);
title('Auto wird aktiv benutzt')

subplot(1,5,5);
Auto_wird_benutzt_in_T_Vektor = T_Vektor;
Auto_wird_benutzt_in_T_Vektor(~Auto_wird_aktiv_benutzt & ~Auto_wird_passiv_benutzt) = NaT;
histogram(hour(Auto_wird_benutzt_in_T_Vektor), 'Normalization','probability')
xlabel('Uhrzeit in h');
ylabel('Relative Häufigkeit über alle Zeitpunkte');
xlim([-1 24]);
xticks([0:4:20,23]);
title('Auto ist nicht zum Laden verfügbar')

figure('units','normalized','outerposition',[0 0 1 1])
plot(T_Vektor,Verbrauch_EAuto.P_L2);
title('Ladekurve eines Elektrofahrzeuges');
ylabel('Wirkleistung in kW');

figure('units','normalized','outerposition',[0 0 1 1])
plot(T_Vektor(44497:44784),Verbrauch_EAuto.P_L2(44497:44784));
title('Ladekurve eines Elektrofahrzeuges für 2 Tage');
ylabel('Wirkleistung in kW');