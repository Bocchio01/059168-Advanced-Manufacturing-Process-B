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
materialNames = {
    'Brass', ...
    'Concrete', ...
    'Glass', ...
    'Lead', ...
    'PVC_Polyvinyl_Chloride', ...
    'Wood_Oak'
    };

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

reset(0);
set(0, 'DefaultFigureNumberTitle', 'off');
set(0, 'DefaultFigureWindowStyle', 'docked');

for material = materialNames
    temperatureData = materialData.(material{1});

    % Plot the temperature profiles as a function of material depth and time
    nexttile;
    hold on
    timeIndices = round(linspace(1, length(timeVec)/5, 5));
    legendEntries = cell(1, length(timeIndices));

    for i = 1:length(timeIndices)
        plot(depthVec(1:25) * 1e3, temperatureData(timeIndices(i), 1:25), "LineWidth", 2);
        legendEntries{i} = ['Time ' num2str(timeVec(timeIndices(i)) * 1e6, '%.2f') ' \mu s'];
    end

    xlabel('Depth (mm)');
    ylabel('Temperature (°C)');
    title(['Temperature Profile in ' replace(material{1}, '_', ' ')]);

    legend(legendEntries, 'Location', 'Best');
    grid on
end


figure;
hold on
for material = materialNames
    temperatureData = materialData.(material{1});

    nexttile;
    hold on
    depthIndices = round(linspace(1, length(depthVec), 5));
    legendEntries = cell(1, length(depthIndices));

    for i = 1:length(depthIndices)
        plot(timeVec * 1e6, temperatureData(:, depthIndices(i)), "LineWidth", 2);
        legendEntries{i} = ['Depth ' num2str(depthVec(depthIndices(i)) * 1e3, 2) ' mm'];
    end

    xlabel('Time (\mu s)');
    ylabel('Temperature (°C)');
    title(['Temperature Profile in ' replace(material{1}, '_', ' ')]);

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
    legendEntries{i} = replace(material{1}, '_', ' ');
    i = i+1;
end

xlabel('Time (\mu s)');
ylabel('Temperature (°C)');
title(['Temperature Profile comparison @depth=' num2str(depthVec(1) * 1e3, 2) ' mm']);
legend(legendEntries, 'Location', 'Best');
grid on


figure;
hold on
for material = materialNames
    temperatureData = materialData.(material{1});

    [T_mesh, X_mesh] = meshgrid(timeVec*1e6, depthVec*1e3);
    nexttile;
    surf(T_mesh', X_mesh', temperatureData, 'EdgeColor', 'none');
    colorbar;
    xlabel('Time (\mus)');
    ylabel('Depth (mm)');
    zlabel('Temperature (°C)');
    title(['1D Temperature Distribution in ' replace(material{1}, '_', ' ')]);
    view(45, 30);
    grid on;
end