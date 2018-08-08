%% Gewichtete Funktionen zwischen der Wahrscheinlichkeit das Auto beginnt zu laden und dem SoC.

figure
SoC_range  = 0.3:0.01:1;
SoC_1      = SoC_range(1);                           % Wenn SoC auf ...%
Laden_1    = 1;                                      % Wahrscheinlichkeit für Laden = 100%.
SoC_2      = SoC_range(end);                         % Wenn SoC auf ...%
Laden_2    = 0;                                      % Wahrscheinlichkeit für Laden = 0%.
Slope_Gew1 = (Laden_1 - Laden_2) / (SoC_1 - SoC_2);  % Steigung für Gewicht = 1 

k_Legend = 1;
% Über verschiedene gewichte
for Gewicht = 1:-0.1:0
    Slope_GewReal = Slope_Gew1 / Gewicht;            % Gewichtete Steigung der Funktion
    Y_AchsenAbsch = Laden_1 - Slope_GewReal * SoC_1; % Y-Achsenabschnitt der Funktion
    Wahr_Ladebeginn = ...
        Slope_GewReal * SoC_range + Y_AchsenAbsch;
    Wahr_Ladebeginn(Wahr_Ladebeginn<0)      = 0;
    Wahr_Ladebeginn(isnan(Wahr_Ladebeginn)) = 0;
    plot(SoC_range,Wahr_Ladebeginn)
    hold all
    legendInfo{k_Legend} = ['Gewicht = ' num2str(Gewicht)];
    k_Legend = k_Legend + 1;
end

legend(legendInfo)
xlabel('SoC');
ylabel('Wahrscheinlichkeit das Auto anfängt zu laden');
