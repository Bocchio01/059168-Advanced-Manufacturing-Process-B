% Thermal_Modelling_1D
%
% Simulates 1D pure conduction heat transfer under a laser thermal pulse.
% The thermal model adopted is: Motionless Extended Planar Heat Source.
% 
% Assumptions:
% - Workpiece
%   - Ti constant
%   - Homogeneous and isotropic
%   - Thermal and physical properties constant
%   - No internal heat source
% - Geometry
%   - 1D semi-infinite (material dimension >= thermal length)
% - Mechanism
%   - Pure conduction
% 
% Author: Tommaso Bocchietti
% Date: 15/10/2023
%
% Instruction:
% Provide in the same folder an excel file containing a set of material
% thermal properties.
%
% Disclaimer: Code is a starting point, may need adaptation for specific cases.
%
% Reference: AMPB (Politecnico di Milano A.A. 2023/2024)

clc
clear variables
close all

%% Variable Declaration

% Material names
materialNames = {'Steel', 'Wood_Oak'};

% Load thermal properties from an external file
thermalProperties = table2struct(readtable('Thermal-Properties.xlsx'));

% Laser power parameter
laserPower = 1e10; % W
thermalPulseDuration = 1e-6; % s

% Time parameter
timeStep = 1e-8; % s
timeVec = 0:timeStep:5*thermalPulseDuration;
timeVec = timeVec + timeStep;

% Depth parameter
depthStep = 1e-6;
depthVec = 0:1e-6:5*1e-5;

% Create a struct to store material properties
materialData = struct();


%% Thermal model

thermalDiffusivity = @(k, Cp, rho) k / (rho * Cp);
ierfc = @(x) -erfc(x) .* x + exp(-(x.^2)) / sqrt(pi);
thermalDistance = @(alpha, t) sqrt(4 * alpha * t);

DT = @(x, t, alpha, k) laserPower * thermalDistance(alpha, t) / k * ierfc(x / thermalDistance(alpha, t));


%% Calculation

for material = materialNames
    materialIndex = find(strcmp({thermalProperties.Material}, material));
    
    Cp = thermalProperties(materialIndex).Specific_Heat_Capacity_J__kgC_;
    K = thermalProperties(materialIndex).Thermal_Conductivity_W__mC_;
    Rho = thermalProperties(materialIndex).Density_kg__m3_;
    Alpha = thermalDiffusivity(K, Cp, Rho);

    % Initialize a matrix to store temperature data
    temperatureMatrix = zeros(length(timeVec), length(depthVec));

    for j = 1:length(timeVec)
        if (j * timeStep <= thermalPulseDuration)
            temperatureMatrix(j, :) = DT(depthVec, timeVec(j), Alpha, K);
        else
            temperatureMatrix(j, :) = DT(depthVec, timeVec(j), Alpha, K) - DT(depthVec, timeVec(j) - thermalPulseDuration, Alpha, K);
        end
    end

    % Store material data in the struct
    materialData.(material{1}) = temperatureMatrix;
end


%% Plots

for material = materialNames
    temperatureData = materialData.(material{1});

    % Plot the temperature profiles as a function of material depth and time
    nexttile;
    hold on
    timeIndices = round(linspace(1, length(timeVec)/5, 5));
    legendEntries = cell(1, length(timeIndices));

    for i = 1:length(timeIndices)
        plot(depthVec, temperatureData(timeIndices(i), :), "LineWidth", 2);
        legendEntries{i} = ['Time ' num2str(timeVec(timeIndices(i)) * 1e6, '%.2f') ' \mu s'];
    end

    xlabel('Depth (m)');
    ylabel('Temperature (°C)');
    title(['Temperature Profile in ' material{1}]);

    legend(legendEntries, 'Location', 'Best');
    grid on


    nexttile;
    hold on
    depthIndices = round(linspace(1, length(depthVec), 5));
    legendEntries = cell(1, length(depthIndices));

    for i = 1:length(depthIndices)
        plot(timeVec * 1e6, temperatureData(:, depthIndices(i)), "LineWidth", 2);
        legendEntries{i} = ['Depth ' num2str(depthVec(depthIndices(i)), 2) ' m'];
    end

    xlabel('Time (\mu s)');
    ylabel('Temperature (°C)');
    title(['Temperature Profile in ' material{1}]);

    legend(legendEntries, 'Location', 'Best');
    grid on
end


figure;
hold on
legendEntries = cell(1, length(materialNames));
i = 1;
for material = materialNames
    temperatureData = materialData.(material{1});
    plot(timeVec * 1e6, temperatureData(:,1), "LineWidth", 2);
    legendEntries{i} = material{1};
    i = i+1;
end

xlabel('Time (\mu s)');
ylabel('Temperature (°C)');
title(['Temperature Profile comparison @depth=' num2str(depthVec(1), 2) ' m']);
legend(legendEntries, 'Location', 'Best');
grid on

