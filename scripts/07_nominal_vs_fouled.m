% Сравнение номинального и загрязнённого объекта

clc; close all;

%% 1. Исходные параметры

mdl_nom = 'vkr';          % номинальная модель
mdl_foul = 'vkr_zagr';    % модель с ухудшенными параметрами объекта

t0 = 300;                 % момент изменения задания, с
r0 = 85;                  % задание до ступеньки, °C
rss = 90;                 % задание после ступеньки, °C

sim_end = 1000;           % длительность моделирования, с

%% 2. Настройки регуляторов

Kp_inner = 40;
Ki_inner = 30;

Kp_outer = 0.016;
Ki_outer = 0.0004;
Kd_outer = 0.04;
Tf_outer = 0.056;

%% 3. Запуск моделирования

load_system(mdl_nom);
load_system(mdl_foul);

out_nom = sim(mdl_nom, 'StopTime', num2str(sim_end));
out_foul = sim(mdl_foul, 'StopTime', num2str(sim_end));

%% 4. Расчёт показателей качества

m_nom = calcMetricsKnownStep(out_nom, t0, r0, rss);
m_foul = calcMetricsKnownStep(out_foul, t0, r0, rss);

%% 5. Вывод результатов

fprintf('\n============================================================\n');
fprintf('НОМИНАЛЬНЫЙ ОБЪЕКТ\n');
fprintf('============================================================\n');

fprintf('Начальная температура y0 = %.4f °C\n', m_nom.y0);
fprintf('Установившаяся температура yss = %.4f °C\n', m_nom.yss);
fprintf('Статическая ошибка e_stat = %.6f °C\n', m_nom.e_stat);
fprintf('Перерегулирование sigma = %.2f %%\n', m_nom.overshoot);
fprintf('Время регулирования t_settle = %.2f с\n', m_nom.t_settle);
fprintf('Время нарастания t_rise = %.2f с\n', m_nom.t_rise);

fprintf('\n============================================================\n');
fprintf('ЗАГРЯЗНЁННЫЙ ОБЪЕКТ\n');
fprintf('============================================================\n');

fprintf('Начальная температура y0 = %.4f °C\n', m_foul.y0);
fprintf('Установившаяся температура yss = %.4f °C\n', m_foul.yss);
fprintf('Статическая ошибка e_stat = %.6f °C\n', m_foul.e_stat);
fprintf('Перерегулирование sigma = %.2f %%\n', m_foul.overshoot);
fprintf('Время регулирования t_settle = %.2f с\n', m_foul.t_settle);
fprintf('Время нарастания t_rise = %.2f с\n', m_foul.t_rise);

%% 6. Чтение сигналов

[t_nom, T_nom] = readSimSignal(out_nom, 'T_meas');
[t_foul, T_foul] = readSimSignal(out_foul, 'T_meas');

%% 7. График сравнения

figure('Color', 'w', 'Position', [100 100 1300 800]);

plot(t_nom, T_nom, 'b', 'LineWidth', 2.2);
hold on;
plot(t_foul, T_foul, 'r--', 'LineWidth', 2.2);

yline(rss, ':k', 'LineWidth', 1.5);
xline(t0, '--k', 'LineWidth', 1.2);

grid on;
box on;

xlabel('Время, с', 'FontSize', 16);
ylabel('Температура, °C', 'FontSize', 16);
title('Сравнение переходных процессов при номинальном и загрязнённом объекте', ...
    'FontSize', 17, ...
    'FontWeight', 'bold');

legend({'Номинальный объект', 'Загрязнённый объект', ...
        'Задание', 'Момент ступеньки'}, ...
    'Location', 'best', ...
    'FontSize', 13);

xlim([250 600]);

set(gca, 'FontSize', 14, 'LineWidth', 1.0);

exportgraphics(gcf, 'nominal_vs_fouled.png', 'Resolution', 300);

%% 8. Расчёт показателей для ступенчатого изменения задания

function m = calcMetricsKnownStep(simOut, t0, r0, rss)

    [t, y] = readSimSignal(simOut, 'T_meas');

    dY = rss - r0;

    pre_idx = t >= (t0 - 20) & t < t0;
    m.y0 = mean(y(pre_idx));

    post_idx = t >= (t(end) - 100);
    m.yss = mean(y(post_idx));

    m.e_stat = abs(rss - m.yss);

    idx_after = t >= t0;
    t_after = t(idx_after);
    y_after = y(idx_after);

    if dY >= 0
        y_peak = max(y_after);
        m.overshoot = max(0, (y_peak - rss) / abs(dY) * 100);
    else
        y_peak = min(y_after);
        m.overshoot = max(0, (rss - y_peak) / abs(dY) * 100);
    end

    band = 0.05 * abs(dY);
    last_outside = find(abs(y_after - rss) > band, 1, 'last');

    if isempty(last_outside)
        m.t_settle = 0;
    else
        m.t_settle = t_after(last_outside) - t0;
    end

    y10 = r0 + 0.1 * dY;
    y90 = r0 + 0.9 * dY;

    if dY >= 0
        idx10 = find((t >= t0) & (y >= y10), 1, 'first');
        idx90 = find((t >= t0) & (y >= y90), 1, 'first');
    else
        idx10 = find((t >= t0) & (y <= y10), 1, 'first');
        idx90 = find((t >= t0) & (y <= y90), 1, 'first');
    end

    if ~isempty(idx10) && ~isempty(idx90)
        m.t_rise = t(idx90) - t(idx10);
    else
        m.t_rise = NaN;
    end
end

%% 9. Чтение сигналов

function [t, y] = readSimSignal(simOut, signalName)
    sig = simOut.(signalName);

    if isa(sig, 'timeseries')
        t = sig.Time(:);
        y = squeeze(sig.Data);
        y = y(:);
        return;
    end

    if isstruct(sig) && isfield(sig, 'time')
        t = sig.time(:);
        y = squeeze(sig.signals.values);
        y = y(:);
        return;
    end

    if isprop(sig, 'Time') && isprop(sig, 'Data')
        t = sig.Time(:);
        y = squeeze(sig.Data);
        y = y(:);
        return;
    end

    error('Не удалось прочитать сигнал %s', signalName);
end
