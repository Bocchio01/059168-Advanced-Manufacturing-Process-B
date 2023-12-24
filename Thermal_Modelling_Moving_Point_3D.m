% Thermal_Modelling_Moving_Point_3D
%
% Simulates temperature distribution in a material under laser irradiation.
% The thermal model adopted is: Steady State Moving Point Heat Source.
%
% Author: Tommaso Bocchietti
% Date: 16/11/2023
%
% Instruction:
% Provide in the same folder an excel file containing a set of experiment
% about track width of the laser trace.
%
% Set 'calibrate_efficiency' to true for efficiency auto calibration.
% Set 'graph' to true for visualization of different graphs.
%
% Disclaimer: Code is a starting point, may need adaptation for specific cases.
%
% Reference: AMPB (Politecnico di Milano A.A. 2023/2024)

clc
clear variables
close all

%% Problem statement

calibrate_efficiency = true;
graph = true * [0 0 1 1 1];

eta_guess = 0.01:0.01:1;
resolution = 5;
scale_factor = 1e-6;

% Material properties: Paint coating
material = struct( ...
    'density', 1450, ...
    'specific_heat_capacity', 2500, ...
    'thermal_conductivity', 0.3, ...
    'vaporization_temperature', 300, ...
    'absorption_coefficient', 1);

% Material properties: Ductile iron @700°C
% material = struct( ...
%     'density', 7100, ...
%     'specific_heat_capacity', 1000, ...
%     'thermal_conductivity', 32, ...
%     'vaporization_temperature', 300, ...
%     'absorption_coefficient', 0.3);
material.thermal_diffusivity = material.thermal_conductivity / (material.density * material.specific_heat_capacity);

% Process parameters
process = struct( ...
    'power', 1600 * 1e-3, ...
    'wavelength', 445, ...
    'focus_point', 0, ...
    'n_passes', 1, ...
    'feed_rate', 800 * 1e-3 / 60, ...
    'efficiency', 1, ...
    'geometrical_correction', 10, ...
    'temperature_ambient', 25);

% Simulation domain
domain = struct( ...
    'eps', scale_factor * (-1000:resolution:50), ...
    'y', scale_factor * (-200:resolution:200), ...
    'z', scale_factor * (0:resolution:20));

% Experimental data
track_widths = table2struct(readtable('Track-Width.xlsx'));
VAP_experimental = mean([track_widths.('Red')]) * scale_factor;
VAP_target = min([track_widths.('Red')]) * scale_factor;

clear track_widths


%% Model defintion
% Here we suppose unitary efficiency and T_environment = 0°C

r = @(eps, y, z) norm([eps, y, process.geometrical_correction * z]);
T = @(eps, y, z) 0 + process.power * material.absorption_coefficient * 1 / (2*pi*material.thermal_conductivity*r(eps, y, z)) * ...
    exp(-process.feed_rate / (2*material.thermal_diffusivity) * (eps + r(eps, y, z)));


%% Model solution (not calibrated)

T_field = zeros( ...
    length(domain.eps), ...
    length(domain.y), ...
    length(domain.z));

tic
for eps_idx = 1:length(domain.eps)
    for y_idx = 1:length(domain.y)
        for z_idx = 1:length(domain.z)
            T_field(eps_idx, y_idx, z_idx) = T(domain.eps(eps_idx), domain.y(y_idx), domain.z(z_idx));
        end
    end
end
toc

clear eps_idx y_idx z_idx


%% Model calibration

if (isnan(process.efficiency) || calibrate_efficiency)

    VAP_error = zeros(length(eta_guess), 1);
    VAP_simulated = zeros(length(eta_guess), 1);

    for i = 1:length(eta_guess)

        VAP_field_XY = contourc( ...
            domain.eps, ...
            domain.y, ...
            squeeze(T_field(:, :, 1))' * eta_guess(i) + process.temperature_ambient, ...
            [material.vaporization_temperature material.vaporization_temperature]);

        VAP_simulated(i) = 2 * max(VAP_field_XY(2, 2:end));
        VAP_error(i) = 100 * abs(VAP_experimental - VAP_simulated(i)) / VAP_experimental;

    end

    process.efficiency = eta_guess(find_index(VAP_error, 0));

end


%% Model solution (calibrated)
% We suppose that material can reach up to vaporization temperature

T_field = T_field * process.efficiency + process.temperature_ambient;

VAP_field_XY = contourc( ...
    domain.eps, ...
    domain.y, ...
    squeeze(T_field(:, :, 1))', ...
    [material.vaporization_temperature material.vaporization_temperature]);

VAP_field_XZ = contourc( ...
    domain.eps, ...
    domain.z, ...
    squeeze(T_field(:, find_index(domain.y, 0), :))', ...
    [material.vaporization_temperature material.vaporization_temperature]);

[VAP_width_half, VAP_width_idx] = max(VAP_field_XY(2, 2:end));
[VAP_depth, VAP_depth_idx] = max(VAP_field_XZ(2, 2:end));

VAP_width = 2 * VAP_width_half;

VAP_width_eps = VAP_field_XY(1, 1 + VAP_width_idx);
VAP_depth_eps = VAP_field_XZ(1, 1 + VAP_depth_idx);

clear VAP_width_half VAP_width_idx VAP_depth_idx


%% Hollow profile
% Here we compute half of the hollow profile that will be usefull to
% visualize how the material surface will be left after the process.

VAP_field_YZ = contourc( ...
    domain.y, ...
    domain.z, ...
    squeeze(T_field(find_index(domain.eps, mean([VAP_width_eps, VAP_depth_eps])), :, :))', ...
    [material.vaporization_temperature material.vaporization_temperature]);

VAP_field_YZ = VAP_field_YZ(:, find_index(VAP_field_YZ(1, :), 0):end);

z_values = linspace(VAP_field_YZ(2, 1), VAP_field_YZ(2, end), 100);
y_values = interp1(VAP_field_YZ(2, :), VAP_field_YZ(1, :), z_values, 'pchip');

hollow_profile = [y_values' z_values'];

clear z_values y_values


%% Output variables

process %#ok<NOPTS>
output = struct( ...
    'VAP_width', VAP_width / scale_factor, ...
    'VAP_depth', VAP_depth / scale_factor, ...
    'units', '\mu') %#ok<NOPTS>



%% Solution visualization

if any(graph)

    T_plot = min(material.vaporization_temperature, T_field);
    domain_plot = struct( ...
        'eps', domain.eps / scale_factor, ...
        'y', domain.y / scale_factor, ...
        'z', domain.z / scale_factor);
    hollow_profile_plot = hollow_profile / scale_factor;

    figs = NaN(sum(graph), 1);

end


%% Temperature distribution, T(space, depth)

if graph(1)

    figure_depth_comparison = figure('Name', 'Temperature distribution at different depth', 'NumberTitle', 'off');
    for z = linspace(min(domain_plot.z), max(domain_plot.z), 3)
        nexttile
        hold on
        grid on
        surf( ...
            domain_plot.eps', ...
            domain_plot.y', ...
            T_plot(:, :, find_index(domain_plot.z, z))')
        cbar = colorbar;
        cbar.Label.String = 'Temperature [°C]';
        axis tight
        view(3);
        title({['Temperature distribution, depth=', num2str(z, '%.2f'), ' [\mum]']})
        xlabel('\xi [\mum]');
        ylabel('Y [\mum]');
        zlabel('T [°C]');
    end

    for z = linspace(min(domain_plot.z), max(domain_plot.z), 3)
        nexttile
        hold on
        grid on
        imagesc( ...
            domain_plot.eps, ...
            domain_plot.y, ...
            squeeze(T_plot(:, :, find_index(domain_plot.z, z))'));
        cbar = colorbar;
        cbar.Label.String = 'Temperature [°C]';
        axis equal tight
        title({['Temperature distribution, depth=', num2str(z, 2), ' [\mum]']})
        xlabel('\xi [\mum]');
        ylabel('Y [\mum]');
    end

    for z = linspace(min(domain_plot.z), max(domain_plot.z), 3)
        nexttile
        hold on
        grid on
        contour( ...
            domain_plot.eps', ...
            domain_plot.y', ...
            T_plot(:, :, find_index(domain_plot.z, z))', ...
            'ShowText', 'on');
        axis equal
        title({['Iso-temperature lines, depth=', num2str(z, '%.2f'), ' [\mum]']})
        xlabel('\xi [\mum]');
        ylabel('Y [\mum]');
    end

    figs(1) = figure_depth_comparison;

end


%% Model calibration, eta

if graph(2)

    figure_calibration = figure('Name', 'Model calibration', 'NumberTitle', 'off');
    if (exist('VAP_error', 'var') && exist('VAP_simulated', 'var') && exist('eta_guess', 'var'))
        nexttile
        hold on
        grid on

        yyaxis left;
        plot(eta_guess, VAP_error, 'b', ...
            'LineWidth', 2);
        ylabel('Error [%]');

        yyaxis right;
        plot(eta_guess, VAP_simulated / scale_factor, 'r', ...
            'LineWidth', 2);
        plot(eta_guess, VAP_experimental * ones(length(VAP_error), 1) / scale_factor, '--k', ...
            'LineWidth', 1);
        ylabel('VAP [\mum]');

        title('VAP error for different \eta')
        xlabel('\eta []');
        legend('Error [%]', 'VAP simulated [\mum]', 'VAP experimental [\mum]')
    end

    figs(2) = figure_calibration;

end


%% VAP analysis

if graph(3)

    figure_VAP_analysis = figure('Name', 'VAP analysis', 'NumberTitle', 'off');
    tiledlayout(4, 2);

    % VAP on the XY plane (@surface)
    nexttile([2 1]);
    hold on
    grid on
    imagesc( ...
        domain_plot.eps, ...
        domain_plot.y, ...
        squeeze(T_plot(:, :, 1))');
    cbar = colorbar;
    cbar.Label.String = 'Temperature [°C]';
    axis tight
    title('XY plane (@surface)')
    xlabel('\xi [\mum]');
    ylabel('Y [\mum]');

    nexttile([2 1]);
    hold on
    grid on
    contour( ...
        domain_plot.eps, ...
        domain_plot.y, ...
        squeeze(T_field(:, :, 1))', ...
        [material.vaporization_temperature material.vaporization_temperature]);
    plot( ...
        [VAP_width_eps, VAP_width_eps] / scale_factor, ...
        [-VAP_width/2, VAP_width/2] / scale_factor, ...
        'LineWidth', 2)
    title({['VAP_{width}=', num2str(VAP_width / scale_factor, '%.2f'), ' [\mum]']})
    xlabel('\xi [\mum]');
    ylabel('Y [\mum]');

    % VAP on the XZ plane (@middle of the material)
    nexttile
    hold on
    grid on
    imagesc( ...
        domain_plot.eps, ...
        domain_plot.z, ...
        squeeze(T_plot(:, find_index(domain_plot.y, 0), :))');
    set(gca, 'ydir', 'reverse')
    cbar = colorbar;
    cbar.Label.String = 'Temperature [°C]';
    axis tight
    title('XZ plane (@middle of the material)')
    xlabel('\xi [\mum]');
    ylabel('Z [\mum]');

    nexttile
    hold on
    grid on
    contour( ...
        domain_plot.eps, ...
        domain_plot.z, ...
        squeeze(T_field(:, find_index(domain_plot.y, 0), :))', ...
        [material.vaporization_temperature material.vaporization_temperature]);
    plot( ...
        [VAP_depth_eps, VAP_depth_eps] / scale_factor, ...
        [0, VAP_depth] / scale_factor, ...
        'LineWidth', 2)
    set(gca, 'ydir', 'reverse')
    title({['VAP_{depth}=', num2str(VAP_depth / scale_factor, '%.2f'), ' [\mum]']})
    xlabel('\xi [\mum]');
    ylabel('Y [\mum]');

    % VAP on the YZ plane (@max VAP depth founded)
    nexttile
    hold on
    grid on
    imagesc( ...
        domain_plot.y, ...
        domain_plot.z, ...
        squeeze(T_plot(find_index(domain.eps, VAP_depth_eps), :, :))');
    set(gca, 'Ydir', 'reverse')
    cbar = colorbar;
    cbar.Label.String = 'Temperature [°C]';
    axis tight
    title('YZ plane (@max VAP_{depth} founded)')
    xlabel('Y [\mum]');
    ylabel('Z [\mum]');

    nexttile
    hold on
    grid on
    contour( ...
        domain_plot.y, ...
        domain_plot.z, ...
        squeeze(T_field(find_index(domain.eps, VAP_depth_eps), :, :))', ...
        [material.vaporization_temperature material.vaporization_temperature]);
    plot( ...
        [0, 0] / scale_factor, ...
        [0, VAP_depth] / scale_factor, ...
        'LineWidth', 2)
    set(gca, 'ydir', 'reverse')
    title({['VAP_{depth}=', num2str(VAP_depth / scale_factor, '%.2f'), ' [\mum]']})
    xlabel('Y [\mum]');
    ylabel('Z [\mum]');

    figs(3) = figure_VAP_analysis;

end


%% VAP 3D visualization

if graph(4)

    figure_melted_region = figure('Name', 'VAP 3D visualization', 'NumberTitle', 'off');
    nexttile
    hold on
    grid on
    [X, Y, Z] = meshgrid(domain_plot.eps, ...
        domain_plot.y, ...
        -domain_plot.z);
    fv = isosurface(X, Y, Z, ...
        permute(T_field, [2, 1, 3]), ...
        material.vaporization_temperature);
    p = patch(fv);
    set(p, ...
        'FaceColor', 'red', ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.3);
    view(3);
    % axis equal
    camlight;
    lighting gouraud;
    title('Melted region @T_{vaporization}')
    xlabel('\xi [\mum]');
    ylabel('Y [\mum]');
    zlabel('Z [\mum]');

    figs(4) = figure_melted_region;

end


%% Hollowed profile

if graph(5)

    figure_hollow_profile = figure('Name', 'Hollowed profile', 'NumberTitle', 'off');
    tiledlayout('vertical')

    for target = [VAP_experimental VAP_target] / scale_factor

        nexttile
        hold on
        grid on
        plot(hollow_profile_plot(:, 1), ...
            -hollow_profile_plot(:, 2), '-b');
        plot(target - hollow_profile_plot(:, 1), ...
            -hollow_profile_plot(:, 2), '-r');
        plot([0 target], [0 0], '--k')
        plot([0 target], [-1 -1] * max(hollow_profile_plot(:, 2)), '-k', 'LineWidth', 2)
        plot([1 1] * target/2, ...
            [min(-hollow_profile_plot(:, 2)) -hollow_profile_plot(find_index(hollow_profile_plot(:, 1), target/2), 2)], '--r')
        title({['Hollow profile, hatch distance=h_d=', num2str(target, '%.2f'), ' [\mum]']})
        xlabel('Y [\mum]');
        ylabel('Z [\mum]');
        legend( ...
            'Half profile #1', ...
            'Half profile #2', ...
            'Previous plane level', ...
            'Ideal plane level', ...
            'Ridge height');
        axis([0 target -max(hollow_profile_plot(:, 2)) 0])

    end

    figs(5) = figure_hollow_profile;

end


%% Reorder graph

for fig_idx = sort(find(graph == true), 'descend')

    figure(figs(fig_idx));

end



%% Functions

function idx = find_index(vector, target)
% FIND_INDEX find the vector index of the closest element
% to a given target.
%
%   idx = FIND_INDEX(vector, target)
%
%   See also FIND.

[~, idx] = min(abs(vector - target));

end

