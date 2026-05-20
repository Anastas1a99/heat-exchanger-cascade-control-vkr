% Расчёт показателей качества внешнего контура регулирования температуры

clc; close all;

%% 1. Исходные параметры

mdl = 'vkr';              % модель каскадной системы управления
t0 = 300;                 % момент подачи ступеньки, с
sim_end = 800;            % длительность моделирования, с
band_percent = 0.05;      % полоса регулирования, доли единицы

%% 2. Настройки регуляторов

Kp_inner = 40;
Ki_inner = 30;

Kp_outer = 0.016;
Ki_outer = 0.0004;
Kd_outer = 0.04;
Tf_outer = 0.056;

%% 3. Запуск моделирования

load_system(mdl);
out = sim(mdl, 'StopTime', num2str(sim_end));

%% 4. Чтение сигналов из SimulationOutput

[t_set, r] = readSimSignal(out, 'T_set');
[t_y, y] = readSimSignal(out, 'T_meas');
[t_u, u] = readSimSignal(out, 'U_valve');
[t_g, g] = readSimSignal(out, 'G_steam');

%% 5. Значения до и после ступеньки

pre_idx_y = t_y >= (t0 - 20) & t_y < t0;
post_idx_y = t_y >= (t_y(end) - 30);

pre_idx_r = t_set >= (t0 - 20) & t_set < t0;
post_idx_r = t_set >= (t_set(end) - 30);

y0 = mean(y(pre_idx_y));          % начальная температура, °C
yss = mean(y(post_idx_y));        % установившаяся температура, °C

r0 = mean(r(pre_idx_r));          % начальное задание, °C
rss = mean(r(post_idx_r));        % установившееся задание, °C

dY = rss - r0;                    % амплитуда ступеньки

%% 6. Статическая ошибка

e_stat = abs(rss - yss);

%% 7. Перерегулирование

y_after = y(t_y >= t0);

if dY >= 0
    y_peak = max(y_after);
    overshoot = max(0, (y_peak - yss) / abs(dY) * 100);
else
    y_peak = min(y_after);
    overshoot = max(0, (yss - y_peak) / abs(dY) * 100);
end

%% 8. Время регулирования

band = band_percent * abs(dY);

idx_after = t_y >= t0;
t_after = t_y(idx_after);
y_after = y(idx_after);

err_band = abs(y_after - yss);
last_outside = find(err_band > band, 1, 'last');

if isempty(last_outside)
    t_settle = 0;
else
    t_settle = t_after(last_outside) - t0;
end

%% 9. Время нарастания

y10 = y0 + 0.1 * dY;
y90 = y0 + 0.9 * dY;

if dY >= 0
    idx10 = find((t_y >= t0) & (y >= y10), 1, 'first');
    idx90 = find((t_y >= t0) & (y >= y90), 1, 'first');
else
    idx10 = find((t_y >= t0) & (y <= y10), 1, 'first');
    idx90 = find((t_y >= t0) & (y <= y90), 1, 'first');
end

if ~isempty(idx10) && ~isempty(idx90)
    t_rise = t_y(idx90) - t_y(idx10);
else
    t_rise = NaN;
end

%% 10. Показатели управляющего сигнала

dt_u = mean(diff(t_u));
sat_time_u = sum(u <= 0.1 | u >= 99.9) * dt_u;

pre_idx_u = t_u >= (t0 - 20) & t_u < t0;
u0 = mean(u(pre_idx_u));

u_after = u(t_u >= t0);
u_max = max(u_after);
u_min = min(u_after);
du_peak = max(abs(u_after - u0));

%% 11. Показатели расхода пара

pre_idx_g = t_g >= (t0 - 20) & t_g < t0;
post_idx_g = t_g >= (t_g(end) - 30);

g0 = mean(g(pre_idx_g));
gss = mean(g(post_idx_g));

g_after = g(t_g >= t0);
g_max = max(g_after);
g_min = min(g_after);
dg_peak = max(abs(g_after - g0));

%% 12. Вывод результатов

fprintf('\n============================================================\n');
fprintf('ПОКАЗАТЕЛИ КАЧЕСТВА ВНЕШНЕГО КОНТУРА\n');
fprintf('============================================================\n');

fprintf('Начальная температура y0 = %.4f °C\n', y0);
fprintf('Установившаяся температура yss = %.4f °C\n', yss);
fprintf('Начальное задание r0 = %.4f °C\n', r0);
fprintf('Установившееся задание rss = %.4f °C\n', rss);
fprintf('Статическая ошибка e_stat = %.6f °C\n', e_stat);
fprintf('Перерегулирование sigma = %.2f %%\n', overshoot);
fprintf('Время регулирования t_settle = %.2f с\n', t_settle);
fprintf('Время нарастания t_rise = %.2f с\n', t_rise);
fprintf('Время насыщения клапана = %.2f с\n', sat_time_u);

fprintf('\n============================================================\n');
fprintf('ПОКАЗАТЕЛИ УПРАВЛЯЮЩЕГО СИГНАЛА\n');
fprintf('============================================================\n');

fprintf('Начальное открытие клапана u0 = %.2f %%\n', u0);
fprintf('Максимум клапана u_max = %.2f %%\n', u_max);
fprintf('Минимум клапана u_min = %.2f %%\n', u_min);
fprintf('Пиковое отклонение клапана = %.2f %%\n', du_peak);

fprintf('\n============================================================\n');
fprintf('ПОКАЗАТЕЛИ РАСХОДА ПАРА\n');
fprintf('============================================================\n');

fprintf('Начальный расход пара g0 = %.4f кг/с\n', g0);
fprintf('Установившийся расход пара gss = %.4f кг/с\n', gss);
fprintf('Максимум расхода пара g_max = %.4f кг/с\n', g_max);
fprintf('Минимум расхода пара g_min = %.4f кг/с\n', g_min);
fprintf('Пиковое отклонение расхода пара = %.4f кг/с\n', dg_peak);

%% 13. График температуры

figure('Color', 'w', 'Position', [100 100 1300 750]);

plot(t_y, y, 'LineWidth', 1.8);
hold on;
plot(t_set, r, '--', 'LineWidth', 1.4);

xline(t0, ':k', 'Ступенька', 'LineWidth', 1.2);
yline(yss + band, ':r', '+5%', 'LineWidth', 1.1);
yline(yss - band, ':r', '-5%', 'LineWidth', 1.1);

grid on;
box on;

xlabel('Время, с', 'FontSize', 14);
ylabel('Температура, °C', 'FontSize', 14);
title('Переходный процесс внешнего контура', ...
    'FontSize', 16, 'FontWeight', 'bold');

legend({'Измеренная температура', 'Задание'}, ...
    'Location', 'best', 'FontSize', 12);

set(gca, 'FontSize', 12, 'LineWidth', 1.0);

exportgraphics(gcf, 'outer_loop_temperature.png', 'Resolution', 300);

%% 14. График управляющего сигнала

figure('Color', 'w', 'Position', [100 100 1300 750]);

plot(t_u, u, 'LineWidth', 1.8);
hold on;

xline(t0, ':k', 'Ступенька', 'LineWidth', 1.2);

grid on;
box on;

xlabel('Время, с', 'FontSize', 14);
ylabel('Открытие клапана, %', 'FontSize', 14);
title('Управляющий сигнал внешнего контура', ...
    'FontSize', 16, 'FontWeight', 'bold');

set(gca, 'FontSize', 12, 'LineWidth', 1.0);

exportgraphics(gcf, 'outer_loop_valve_signal.png', 'Resolution', 300);

%% 15. График расхода пара

figure('Color', 'w', 'Position', [100 100 1300 750]);

plot(t_g, g, 'LineWidth', 1.8);
hold on;

xline(t0, ':k', 'Ступенька', 'LineWidth', 1.2);

grid on;
box on;

xlabel('Время, с', 'FontSize', 14);
ylabel('Расход пара, кг/с', 'FontSize', 14);
title('Изменение расхода пара при работе внешнего контура', ...
    'FontSize', 16, 'FontWeight', 'bold');

set(gca, 'FontSize', 12, 'LineWidth', 1.0);

exportgraphics(gcf, 'outer_loop_steam_flow.png', 'Resolution', 300);

%% 16. Чтение сигналов

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
