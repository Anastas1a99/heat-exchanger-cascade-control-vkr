% Моделирование возмущения по входной температуре продукта

clc; close all;

%% 1. Исходные параметры

mdl = 'vkr';              % модель каскадной системы управления
t0 = 300;                 % момент подачи возмущения, с
sim_end = 800;            % длительность моделирования, с
Tzad = 85;                % заданная температура, °C

x1 = 230;                 % левая граница графиков, с
x2 = 700;                 % правая граница графиков, с

%% 2. Настройки регуляторов

Kp_inner = 40;
Ki_inner = 30;

Kp_outer = 0.016;
Ki_outer = 0.0004;
Kd_outer = 0.04;
Tf_outer = 0.056;

%% 3. Задание сценария возмущения

load_system(mdl);

set_param([mdl '/ΔG_продукта'], 'Before', '0', 'After', '0');
set_param([mdl '/ΔT_вх'],       'Before', '0', 'After', '-10');
set_param([mdl '/ΔT_пара'],     'Before', '0', 'After', '0');

%% 4. Запуск моделирования

out = sim(mdl, 'StopTime', num2str(sim_end));

%% 5. Чтение сигналов

[t, T] = readSimSignal(out, 'T_meas');
[tU, U] = readSimSignal(out, 'U_valve');
[tG, G] = readSimSignal(out, 'G_steam');

%% 6. Расчёт показателей температуры

pre_idx = t >= (t0 - 20) & t < t0;
T0 = mean(T(pre_idx));

post_idx = t >= t0;
t_post = t(post_idx);
T_post = T(post_idx);

[Tmin, i_min] = min(T_post);
t_min = t_post(i_min);

drop = T0 - Tmin;

Tmax = max(T_post);
overshoot = max(0, (Tmax - Tzad) / abs(drop) * 100);

band = 0.05 * abs(drop);
err = abs(T_post - Tzad);
last_outside = find(err > band, 1, 'last');

if isempty(last_outside)
    t_rec = 0;
else
    t_rec = t_post(last_outside) - t0;
end

%% 7. Расчёт показателей управляющего сигнала

pre_idx_U = tU >= (t0 - 20) & tU < t0;
U0 = mean(U(pre_idx_U));

post_idx_U = tU >= t0;
U_post = U(post_idx_U);
tU_post = tU(post_idx_U);

[Umax, i_umax] = max(U_post);
t_umax = tU_post(i_umax);

%% 8. Расчёт показателей расхода пара

pre_idx_G = tG >= (t0 - 20) & tG < t0;
G0 = mean(G(pre_idx_G));

post_idx_G = tG >= t0;
G_post = G(post_idx_G);
tG_post = tG(post_idx_G);

[Gmax, i_gmax] = max(G_post);
t_gmax = tG_post(i_gmax);

%% 9. Вывод результатов

fprintf('\n============================================================\n');
fprintf('ВОЗМУЩЕНИЕ ПО ВХОДНОЙ ТЕМПЕРАТУРЕ ПРОДУКТА\n');
fprintf('============================================================\n');

fprintf('Температура до возмущения T0 = %.4f °C\n', T0);
fprintf('Минимальная температура Tmin = %.4f °C\n', Tmin);
fprintf('Максимальное отклонение температуры = %.4f °C\n', drop);
fprintf('Время восстановления = %.2f с\n', t_rec);
fprintf('Перерегулирование при восстановлении = %.2f %%\n', overshoot);

fprintf('\nУправляющий сигнал:\n');
fprintf('Исходное открытие клапана U0 = %.4f %%\n', U0);
fprintf('Максимальное открытие клапана Umax = %.4f %%\n', Umax);

fprintf('\nРасход пара:\n');
fprintf('Исходный расход пара G0 = %.4f кг/с\n', G0);
fprintf('Максимальный расход пара Gmax = %.4f кг/с\n', Gmax);

%% 10. График температуры продукта

figure('Color', 'w', 'Position', [100 100 1400 850]);

plot(t, T, 'b', 'LineWidth', 2.2);
hold on;

yline(Tzad, '--', ...
    'Color', [0.85 0.33 0.10], ...
    'LineWidth', 1.8);

xline(t0, '--k', ...
    'Возмущение', ...
    'LineWidth', 1.2);

plot(t_min, Tmin, ...
    'ko', ...
    'MarkerFaceColor', 'k', ...
    'MarkerSize', 7);

grid on;
box on;

xlabel('Время, с', 'FontSize', 16);
ylabel('Температура, °C', 'FontSize', 16);
title('Переходный процесс температуры продукта', ...
    'FontSize', 18, ...
    'FontWeight', 'bold');

legend({'Температура продукта', 'Задание', ...
        'Момент возмущения', 'Минимум температуры'}, ...
    'Location', 'best', ...
    'FontSize', 13);

xlim([x1 x2]);

mask = t >= x1 & t <= x2;
ymin = min(T(mask));
ymax = max(T(mask));
padding = 0.20 * (ymax - ymin + 0.05);
ylim([ymin - padding, ymax + padding]);

set(gca, 'FontSize', 14, 'LineWidth', 1.0);

text(x1 + 4, Tzad - 0.1, ...
    'Установившийся режим', ...
    'FontSize', 13);

text(t_min - 40, Tmin - 0.1, ...
    sprintf('Провал = %.2f °C', drop), ...
    'FontSize', 14);

exportgraphics(gcf, 'ris_3_7_inlet_temperature_temperature.png', ...
    'Resolution', 300);

%% 11. График управляющего сигнала

figure('Color', 'w', 'Position', [100 100 1300 800]);

plot(tU, U, 'b', 'LineWidth', 2.2);
hold on;

yline(U0, '--', ...
    'Color', [0.85 0.33 0.10], ...
    'LineWidth', 1.8);

xline(t0, '--k', ...
    'Возмущение', ...
    'LineWidth', 1.2);

plot(t_umax, Umax, ...
    'ko', ...
    'MarkerFaceColor', 'k', ...
    'MarkerSize', 6);

grid on;
box on;

xlabel('Время, с', 'FontSize', 16);
ylabel('Открытие клапана, %', 'FontSize', 16);
title('Изменение управляющего сигнала', ...
    'FontSize', 18, ...
    'FontWeight', 'bold');

legend({'Управляющий сигнал', 'Исходный уровень', ...
        'Момент возмущения', 'Максимальное открытие'}, ...
    'Location', 'best', ...
    'FontSize', 13);

xlim([x1 x2]);

maskU = tU >= x1 & tU <= x2;
yminU = min(U(maskU));
ymaxU = max(U(maskU));
paddingU = 0.15 * (ymaxU - yminU + 0.5);
ylim([yminU - paddingU, ymaxU + paddingU]);

set(gca, 'FontSize', 14, 'LineWidth', 1.0);

text(x1 + 5, U0 - 0.2, ...
    'Исходное открытие клапана', ...
    'FontSize', 13);

text(t_umax + 5, Umax + 0.3, ...
    sprintf('Максимальное открытие = %.2f %%', Umax), ...
    'FontSize', 13);

exportgraphics(gcf, 'ris_3_8_inlet_temperature_valve_signal.png', ...
    'Resolution', 300);

%% 12. График расхода пара

figure('Color', 'w', 'Position', [100 100 1300 800]);

plot(tG, G, 'b', 'LineWidth', 2.2);
hold on;

yline(G0, '--', ...
    'Color', [0.85 0.33 0.10], ...
    'LineWidth', 1.8);

xline(t0, '--k', ...
    'Возмущение', ...
    'LineWidth', 1.2);

plot(t_gmax, Gmax, ...
    'ko', ...
    'MarkerFaceColor', 'k', ...
    'MarkerSize', 6);

grid on;
box on;

xlabel('Время, с', 'FontSize', 16);
ylabel('Расход пара, кг/с', 'FontSize', 16);
title('Изменение расхода греющего пара', ...
    'FontSize', 18, ...
    'FontWeight', 'bold');

legend({'Фактический расход пара', 'Исходный уровень', ...
        'Момент возмущения', 'Максимальный расход'}, ...
    'Location', 'best', ...
    'FontSize', 13);

xlim([x1 x2]);

maskG = tG >= x1 & tG <= x2;
yminG = min(G(maskG));
ymaxG = max(G(maskG));
paddingG = 0.15 * (ymaxG - yminG + 0.01);
ylim([yminG - paddingG, ymaxG + paddingG]);

set(gca, 'FontSize', 14, 'LineWidth', 1.0);

text(x1 + 5, G0 - 0.005, ...
    'Исходный расход пара', ...
    'FontSize', 13);

text(t_gmax + 5, Gmax + 0.005, ...
    sprintf('Максимальный расход = %.3f кг/с', Gmax), ...
    'FontSize', 13);

exportgraphics(gcf, 'ris_3_9_inlet_temperature_steam_flow.png', ...
    'Resolution', 300);

%% 13. Чтение сигналов

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
