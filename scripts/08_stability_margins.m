% Расчёт запасов устойчивости внешнего контура

clc; close all;

%% 1. Исходные параметры

mdl = 'vkr';              % модель каскадной системы управления

%% 2. Настройки регуляторов

Kp_inner = 40;
Ki_inner = 30;

Kp_outer = 0.016;
Ki_outer = 0.0004;
Kd_outer = 0.04;
Tf_outer = 0.056;

assignin('base', 'Kp_inner', Kp_inner);
assignin('base', 'Ki_inner', Ki_inner);

assignin('base', 'Kp_outer', Kp_outer);
assignin('base', 'Ki_outer', Ki_outer);
assignin('base', 'Kd_outer', Kd_outer);
assignin('base', 'Tf_outer', Tf_outer);

%% 3. Загрузка модели

load_system(mdl);

%% 4. Вывод модели в установившийся режим

simIn = Simulink.SimulationInput(mdl);

simIn = simIn.setVariable('Kp_inner', Kp_inner);
simIn = simIn.setVariable('Ki_inner', Ki_inner);

simIn = simIn.setVariable('Kp_outer', Kp_outer);
simIn = simIn.setVariable('Ki_outer', Ki_outer);
simIn = simIn.setVariable('Kd_outer', Kd_outer);
simIn = simIn.setVariable('Tf_outer', Tf_outer);

simIn = simIn.setModelParameter( ...
    'StopTime', '300', ...
    'SaveFinalState', 'on', ...
    'SaveOperatingPoint', 'on');

out = sim(simIn);
op = out.xFinal;

%% 5. Точки линейного анализа

io = getlinio(mdl);

fprintf('\n============================================================\n');
fprintf('ТОЧКИ ЛИНЕЙНОГО АНАЛИЗА\n');
fprintf('============================================================\n');
disp(io);

%% 6. Линеаризация внешнего контура

Pext = linearize(mdl, io, op);

fprintf('\n============================================================\n');
fprintf('ЛИНЕАРИЗОВАННЫЙ ОБЪЕКТ ВНЕШНЕГО КОНТУРА\n');
fprintf('============================================================\n');
disp(Pext);

%% 7. Передаточная функция внешнего ПИД-регулятора

Cext = pid(Kp_outer, Ki_outer, Kd_outer, Tf_outer);

%% 8. Разомкнутый внешний контур

Lext = minreal(series(Cext, Pext));

%% 9. Расчёт запасов устойчивости

[Gm, Pm, Wcg, Wcp] = margin(Lext);

if isinf(Gm)
    GM_dB = Inf;
else
    GM_dB = 20 * log10(Gm);
end

fprintf('\n============================================================\n');
fprintf('ЗАПАСЫ УСТОЙЧИВОСТИ ВНЕШНЕГО КОНТУРА\n');
fprintf('============================================================\n');

fprintf('Запас по амплитуде GM = %.4f\n', Gm);
fprintf('Запас по амплитуде GM_dB = %.2f дБ\n', GM_dB);
fprintf('Запас по фазе PM = %.2f град\n', Pm);
fprintf('Частота пересечения по фазе Wcg = %.4f рад/с\n', Wcg);
fprintf('Частота пересечения по амплитуде Wcp = %.4f рад/с\n', Wcp);

%% 10. Построение ЛАЧХ и ЛФЧХ

w = logspace(-2, 2, 1000);

[mag, phase, wout] = bode(Lext, w);

mag = squeeze(mag);
phase = squeeze(phase);
mag_dB = 20 * log10(mag);

if isfinite(Wcg) && Wcg > 0
    mag_at_Wcg = interp1(wout, mag_dB, Wcg, 'linear', 'extrap');
else
    mag_at_Wcg = NaN;
end

if isfinite(Wcp) && Wcp > 0
    phase_at_Wcp = interp1(wout, phase, Wcp, 'linear', 'extrap');
else
    phase_at_Wcp = NaN;
end

figure('Color', 'w', 'Position', [100 100 1350 900]);

%% 11. ЛАЧХ

subplot(2, 1, 1);

semilogx(wout, mag_dB, 'b', 'LineWidth', 2.2);
hold on;

yline(0, '--k', 'LineWidth', 1.0);

if isfinite(Wcp) && Wcp > 0
    xline(Wcp, '--r', 'LineWidth', 1.0);
    plot(Wcp, 0, 'ro', ...
        'MarkerFaceColor', 'r', ...
        'MarkerSize', 6);
end

if isfinite(Wcg) && Wcg > 0 && isfinite(mag_at_Wcg)
    plot(Wcg, mag_at_Wcg, 'ko', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 6);
end

grid on;
box on;

ylabel('Амплитуда, дБ', 'FontSize', 15);
title('ЛАЧХ и ЛФЧХ разомкнутого внешнего контура', ...
    'FontSize', 18, ...
    'FontWeight', 'bold');

xlim([1e-2 1e2]);
ylim([-160 20]);

set(gca, 'FontSize', 13, 'LineWidth', 1.0);

if isfinite(Wcp) && Wcp > 0
    text(0.045, 8, ...
        sprintf('\\omega_{cp} = %.4f рад/с', Wcp), ...
        'FontSize', 12, ...
        'Color', 'r');
end

if isfinite(Wcg) && Wcg > 0 && isfinite(mag_at_Wcg)
    text(Wcg * 1.08, mag_at_Wcg + 6, ...
        sprintf('GM = %.2f дБ', GM_dB), ...
        'FontSize', 12);
end

%% 12. ЛФЧХ

subplot(2, 1, 2);

semilogx(wout, phase, 'b', 'LineWidth', 2.2);
hold on;

yline(-180, '--k', 'LineWidth', 1.0);

if isfinite(Wcg) && Wcg > 0
    xline(Wcg, '--r', 'LineWidth', 1.0);
    plot(Wcg, -180, 'ro', ...
        'MarkerFaceColor', 'r', ...
        'MarkerSize', 6);
end

if isfinite(Wcp) && Wcp > 0 && isfinite(phase_at_Wcp)
    plot(Wcp, phase_at_Wcp, 'ko', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 6);
end

grid on;
box on;

xlabel('Частота, рад/с', 'FontSize', 15);
ylabel('Фаза, град', 'FontSize', 15);

xlim([1e-2 1e2]);
ylim([-270 -60]);

set(gca, 'FontSize', 13, 'LineWidth', 1.0);

if isfinite(Wcp) && Wcp > 0 && isfinite(phase_at_Wcp)
    text(Wcp * 1.08, phase_at_Wcp + 10, ...
        sprintf('PM = %.2f^\\circ', Pm), ...
        'FontSize', 12);
end

if isfinite(Wcg) && Wcg > 0
    text(Wcg * 1.08, -170, ...
        sprintf('\\omega_{cg} = %.4f рад/с', Wcg), ...
        'FontSize', 12, ...
        'Color', 'r');
end

annotation('textbox', [0.72 0.81 0.16 0.09], ...
    'String', sprintf('GM = %.2f дБ\nPM = %.2f°', GM_dB, Pm), ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', 'w', ...
    'FontSize', 13);

exportgraphics(gcf, 'stability_margins_outer_loop.png', ...
    'Resolution', 300);
