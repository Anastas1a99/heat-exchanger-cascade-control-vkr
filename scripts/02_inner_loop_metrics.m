% Расчёт показателей качества внутреннего контура регулирования расхода пара

clc; close all;

%% 1. Исходные параметры

mdl = 'vkr';              % модель каскадной системы управления
t0 = 300;                 % момент подачи ступеньки, с
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
out = sim(mdl);

%% 4. Чтение сигналов из SimulationOutput

[t_set, r] = readSimSignal(out, 'G_steam_set');
[t_y, y] = readSimSignal(out, 'G_steam');
[t_u, u] = readSimSignal(out, 'U_valve');

%% 5. Значения до и после ступеньки

pre_idx = t_y >= (t0 - 5) & t_y < t0;
post_idx = t_y >= (t_y(end) - 5);

y0 = mean(y(pre_idx));        % начальное значение расхода пара, кг/с
yss = mean(y(post_idx));      % установившееся значение расхода пара, кг/с

r0 = mean(r(t_set >= (t0 - 5) & t_set < t0));        % начальное задание, кг/с
rss = mean(r(t_set >= (t_set(end) - 5)));            % установившееся задание, кг/с

dY = rss - r0;                % амплитуда ступенчатого изменения задания

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
sat_time = sum(u <= 0.1 | u >= 99.9) * dt_u;

u0 = mean(u(t_u >= (t0 - 5) & t_u < t0));
u_after = u(t_u >= t0);

u_max = max(u_after);
u_min = min(u_after);
du_peak = max(abs(u_after - u0));

%% 11. Вывод результатов

fprintf('\n============================================================\n');
fprintf('ПОКАЗАТЕЛИ КАЧЕСТВА ВНУТРЕННЕГО КОНТУРА\n');
fprintf('============================================================\n');

fprintf('Начальное значение расхода y0 = %.4f кг/с\n', y0);
fprintf('Установившееся значение расхода yss = %.4f кг/с\n', yss);
fprintf('Начальное задание r0 = %.4f кг/с\n', r0);
fprintf('Установившееся задание rss = %.4f кг/с\n', rss);
fprintf('Статическая ошибка e_stat = %.6f кг/с\n', e_stat);
fprintf('Перерегулирование sigma = %.2f %%\n', overshoot);
fprintf('Время регулирования t_settle = %.2f с\n', t_settle);
fprintf('Время нарастания t_rise = %.2f с\n', t_rise);

fprintf('\n============================================================\n');
fprintf('ПОКАЗАТЕЛИ УПРАВЛЯЮЩЕГО СИГНАЛА\n');
fprintf('============================================================\n');

fprintf('Время насыщения клапана = %.2f с\n', sat_time);
fprintf('Начальное открытие клапана u0 = %.2f %%\n', u0);
fprintf('Максимум клапана u_max = %.2f %%\n', u_max);
fprintf('Минимум клапана u_min = %.2f %%\n', u_min);
fprintf('Пиковое отклонение клапана = %.2f %%\n', du_peak);

%% 12. График расхода пара

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
ylabel('Расход пара, кг/с', 'FontSize', 14);
title('Переходный процесс внутреннего контура', ...
    'FontSize', 16, 'FontWeight', 'bold');

legend({'Фактический расход', 'Задание'}, ...
    'Location', 'best', 'FontSize', 12);

set(gca, 'FontSize', 12, 'LineWidth', 1.0);

exportgraphics(gcf, 'inner_loop_steam_flow.png', 'Resolution', 300);

%% 13. График управляющего сигнала

figure('Color', 'w', 'Position', [100 100 1300 750]);

plot(t_u, u, 'LineWidth', 1.8);
hold on;

xline(t0, ':k', 'Ступенька', 'LineWidth', 1.2);

grid on;
box on;

xlabel('Время, с', 'FontSize', 14);
ylabel('Открытие клапана, %', 'FontSize', 14);
title('Управляющий сигнал внутреннего контура', ...
    'FontSize', 16, 'FontWeight', 'bold');

set(gca, 'FontSize', 12, 'LineWidth', 1.0);

exportgraphics(gcf, 'inner_loop_valve_signal.png', 'Resolution', 300);

%% 14. Чтение сигналов

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
